import Foundation
import XCTest
@testable import HeardockCore

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !data.isEmpty {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

func response(_ request: URLRequest, status: Int, body: String = "{}") -> (HTTPURLResponse, Data) {
    let http = HTTPURLResponse(
        url: request.url!,
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
    )!
    return (http, Data(body.utf8))
}

func bodyData(_ request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let size = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: size)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }
    return data
}

@MainActor
final class HeardockCoreTests: XCTestCase {
    private var suites: [String] = []

    override func setUp() {
        super.setUp()
        MockURLProtocol.handler = nil
        suites = []
    }

    override func tearDown() {
        for suite in suites {
            UserDefaults().removePersistentDomain(forName: suite)
        }
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeClient(queueServerErrors: Bool = false, suite: String? = nil) -> (Heardock, String) {
        let name = suite ?? "heardock.tests.\(UUID().uuidString)"
        if !suites.contains(name) { suites.append(name) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = Heardock()
        client.configure(HeardockConfig(
            publicKey: "hd_pub_test",
            baseURL: URL(string: "https://example.test")!,
            requestTimeout: 2,
            queueServerErrors: queueServerErrors,
            suiteName: name,
            session: session
        ))
        return (client, name)
    }

    func testSubmitSendsTheDocumentedContract() async throws {
        var captured: URLRequest?
        MockURLProtocol.handler = { request in
            captured = request
            return response(request, status: 201, body: """
            {"id":"fb_01TEST","status":"new","created_at":"2026-11-06T10:00:00.123Z","device_id":"dev_01TEST"}
            """)
        }

        let (client, _) = makeClient()
        client.setContext(screen: "Settings > Send feedback")
        let result = try await client.submit(message: "  Export freezes  ", category: .bug)

        XCTAssertFalse(result.queued)
        XCTAssertEqual(result.id, "fb_01TEST")
        XCTAssertEqual(result.status, "new")

        let request = try XCTUnwrap(captured)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/feedback")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer hd_pub_test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Heardock-Device")?.count, 43)
        XCTAssertFalse((request.value(forHTTPHeaderField: "Idempotency-Key") ?? "").isEmpty)

        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: bodyData(request)) as? [String: Any]
        )
        XCTAssertEqual(json["message"] as? String, "Export freezes")
        XCTAssertEqual(json["category"] as? String, "bug")
        let context = try XCTUnwrap(json["context"] as? [String: Any])
        XCTAssertEqual(context["platform"] as? String, "macos")
        XCTAssertEqual(context["screen"] as? String, "Settings > Send feedback")
        XCTAssertNil(json["user"])
    }

    func testServerErrorIsSurfacedWhenServerErrorsAreNotQueued() async throws {
        MockURLProtocol.handler = { request in
            response(request, status: 500, body: #"{"error":{"code":"internal","message":"boom"}}"#)
        }
        let (client, _) = makeClient(queueServerErrors: false)

        do {
            _ = try await client.submit(message: "Hello")
            XCTFail("Expected a thrown error")
        } catch let error as HeardockError {
            XCTAssertEqual(error.code, .server)
            XCTAssertEqual(error.statusCode, 500)
        }
        XCTAssertEqual(client.pendingCount, 0)
    }

    func testServerErrorIsQueuedWhenConfigured() async throws {
        MockURLProtocol.handler = { request in
            response(request, status: 503, body: "{}")
        }
        let (client, _) = makeClient(queueServerErrors: true)

        let result = try await client.submit(message: "Hello")
        XCTAssertTrue(result.queued)
        XCTAssertEqual(client.pendingCount, 1)
    }

    func testOfflineSubmissionQueuesAndFlushes() async throws {
        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let (client, suite) = makeClient()

        let queued = try await client.submit(message: "Offline note")
        XCTAssertTrue(queued.queued)
        XCTAssertEqual(client.pendingCount, 1)

        // A fresh client with the same suite restores the queue.
        let (restored, _) = makeClient(suite: suite)
        XCTAssertEqual(restored.pendingCount, 1)

        MockURLProtocol.handler = { request in
            response(request, status: 201, body: #"{"id":"fb_01QUEUED","status":"new"}"#)
        }
        let report = await restored.flushQueue()
        XCTAssertEqual(report.sent, 1)
        XCTAssertEqual(report.pending, 0)
        XCTAssertEqual(restored.pendingCount, 0)
    }

    func testThreadsAndThreadDecode() async throws {
        MockURLProtocol.handler = { request in
            switch request.url?.path {
            case "/v1/threads":
                return response(request, status: 200, body: """
                {"data":[{"id":"fb_1","category":"idea","message":"Hi","status":"in_progress",
                "created_at":"2026-11-06T10:00:00.123Z","last_reply_at":"2026-11-06T11:00:00.000Z","reply_count":1}]}
                """)
            default:
                return response(request, status: 200, body: """
                {"id":"fb_1","category":"idea","message":"Hi","status":"in_progress",
                "created_at":"2026-11-06T10:00:00.123Z",
                "messages":[{"id":"tm_1","author":"team","body":"Thanks","created_at":"2026-11-06T11:00:00.000Z"}]}
                """)
            }
        }
        let (client, _) = makeClient()

        await client.refreshHistory()
        XCTAssertEqual(client.history.count, 1)
        XCTAssertEqual(client.history.first?.category, .idea)
        XCTAssertEqual(client.history.first?.replyCount, 1)

        let thread = try await client.loadThread(id: "fb_1")
        XCTAssertEqual(thread.messages.count, 1)
        XCTAssertEqual(thread.messages.first?.body, "Thanks")
        XCTAssertTrue(thread.messages.first?.isFromTeam ?? false)
    }

    func testDeleteAcceptsAnAlreadyMissingNote() async throws {
        var method: String?
        MockURLProtocol.handler = { request in
            method = request.httpMethod
            return response(request, status: 404, body: #"{"error":{"code":"not_found"}}"#)
        }
        let (client, _) = makeClient()
        try await client.removeThread(id: "fb_1")
        XCTAssertEqual(method, "DELETE")
    }

    func testDeviceTokenIsStablePerProject() async throws {
        var tokens: [String] = []
        MockURLProtocol.handler = { request in
            tokens.append(request.value(forHTTPHeaderField: "X-Heardock-Device") ?? "")
            return response(request, status: 201, body: #"{"id":"fb_1","status":"new"}"#)
        }
        let (client, suite) = makeClient()
        _ = try await client.submit(message: "One")
        let (second, _) = makeClient(suite: suite)
        _ = try await second.submit(message: "Two")

        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0], tokens[1])
        XCTAssertEqual(tokens[0].count, 43)
        XCTAssertTrue(DeviceIdentity.isValid(tokens[0]))
    }

    /// The picker must match the Flutter sheet and the hosted page: four
    /// kinds, with `other` kept as the wire fallback only.
    func testSelectableCategoriesMatchFlutterAndWeb() {
        XCTAssertEqual(FeedbackCategory.selectable, [.bug, .idea, .question, .praise])
        XCTAssertFalse(FeedbackCategory.selectable.contains(.other))
    }

    /// A note waiting in the offline queue is a list row of its own: the entry
    /// point must not treat this device as "no feedback yet".
    func testQueuedNoteAppearsInThreads() async throws {
        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let (client, _) = makeClient()

        let result = try await client.submit(message: "Offline note", category: .bug)
        XCTAssertTrue(result.queued)
        XCTAssertTrue(client.history.isEmpty)
        XCTAssertEqual(client.threads.count, 1)

        let queued = try XCTUnwrap(client.threads.first)
        XCTAssertTrue(queued.pending)
        XCTAssertEqual(queued.status, "queued")
        XCTAssertEqual(queued.message, "Offline note")
        XCTAssertEqual(queued.category, .bug)

        // The local row opens without a network round trip.
        let local = try await client.loadThread(id: queued.id)
        XCTAssertTrue(local.pending)
        XCTAssertEqual(local.id, queued.id)
    }

    /// The cached list survives a fresh launch and a failed refresh, so a
    /// device that sent before never looks new again.
    func testCachedHistorySurvivesAFailedRefresh() async throws {
        MockURLProtocol.handler = { request in
            response(request, status: 200, body: """
            {"data":[{"id":"fb_1","category":"bug","message":"Hi","status":"new",
            "created_at":"2026-11-10T10:00:00.000Z"}]}
            """)
        }
        let (client, suite) = makeClient()
        await client.refreshHistory()
        XCTAssertEqual(client.history.count, 1)

        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let (restored, _) = makeClient(suite: suite)
        XCTAssertEqual(restored.history.count, 1, "the snapshot is hydrated at launch")

        await restored.refreshHistory()
        XCTAssertEqual(restored.history.count, 1, "a failed read keeps the snapshot")
        XCTAssertEqual(restored.threads.count, 1)
        XCTAssertNotNil(restored.historyError)
    }

    /// `queueServerErrors` only decides whether a *new* submission is queued.
    /// A note already saved must survive a 5xx on retry instead of vanishing.
    func testQueuedNoteSurvivesServerErrors() async throws {
        var offline = true
        MockURLProtocol.handler = { request in
            if offline { throw URLError(.notConnectedToInternet) }
            return response(request, status: 500, body: #"{"error":{"code":"internal"}}"#)
        }
        let (client, _) = makeClient(queueServerErrors: false)

        let result = try await client.submit(message: "Keep me")
        XCTAssertTrue(result.queued)

        offline = false
        let report = await client.flushQueue()
        XCTAssertEqual(report.dropped, 0)
        XCTAssertEqual(report.pending, 1)
        XCTAssertEqual(client.pendingCount, 1)
    }

    func testRemovingAQueuedNoteDropsItLocally() async throws {
        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let (client, _) = makeClient()
        _ = try await client.submit(message: "Offline note")
        let queued = try XCTUnwrap(client.threads.first)

        try await client.removeThread(id: queued.id)
        XCTAssertTrue(client.threads.isEmpty)
        XCTAssertEqual(client.pendingCount, 0)
    }

    func testLocalizationUpdateReplacesLocaleAndOverrides() {
        let (client, _) = makeClient()
        let revision = client.localizationRevision

        client.updateLocalization(
            locale: "fr-FR",
            strings: ["title": "Envoyer un commentaire"]
        )

        XCTAssertEqual(client.config?.locale, "fr-FR")
        XCTAssertEqual(client.config?.strings["title"], "Envoyer un commentaire")
        XCTAssertEqual(client.localizationRevision, revision + 1)

        client.updateLocalization()
        XCTAssertNil(client.config?.locale)
        XCTAssertEqual(client.config?.strings, [:])
    }
}
