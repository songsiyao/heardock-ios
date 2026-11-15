import Foundation

/// Thin REST client for `/v1/feedback` and `/v1/threads`.
struct HeardockAPI {
    private let config: HeardockConfig
    private let deviceToken: String
    private let session: URLSession

    init(config: HeardockConfig, deviceToken: String) {
        self.config = config
        self.deviceToken = deviceToken
        if let injected = config.session {
            session = injected
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = config.requestTimeout
            configuration.timeoutIntervalForResource = max(30, config.requestTimeout * 2)
            configuration.httpAdditionalHeaders = ["Accept": "application/json"]
            session = URLSession(configuration: configuration)
        }
    }

    func submit(_ draft: HeardockDraft, idempotencyKey: String) async throws -> HeardockResult {
        var request = makeRequest(path: "v1/feedback", method: "POST")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        do {
            request.httpBody = try JSONEncoder().encode(draft)
        } catch {
            throw HeardockError(code: .invalidRequest)
        }
        let data = try await send(request)
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = object["id"] as? String else {
            throw HeardockError(code: .invalidResponse)
        }
        return HeardockResult(
            id: id,
            status: object["status"] as? String ?? "new",
            createdAt: HeardockDate.parse(object["created_at"] as? String)
        )
    }

    func listThreads() async throws -> [HeardockThread] {
        let data = try await send(makeRequest(path: "v1/threads"))
        do {
            return try JSONDecoder().decode(HeardockThreadEnvelope.self, from: data).data
        } catch {
            throw HeardockError(code: .invalidResponse)
        }
    }

    func thread(id: String) async throws -> HeardockThread {
        let data = try await send(makeRequest(path: "v1/threads/\(escaped(id))"))
        do {
            return try JSONDecoder().decode(HeardockThread.self, from: data)
        } catch {
            throw HeardockError(code: .invalidResponse)
        }
    }

    func deleteThread(id: String) async throws {
        let request = makeRequest(path: "v1/threads/\(escaped(id))", method: "DELETE")
        do {
            _ = try await send(request)
        } catch let error as HeardockError where error.code == .notFound {
            // Already gone is as good as removed.
            return
        }
    }

    private func makeRequest(path: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: config.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = config.requestTimeout
        request.setValue("Bearer \(config.publicKey)", forHTTPHeaderField: "Authorization")
        request.setValue(deviceToken, forHTTPHeaderField: "X-Heardock-Device")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func escaped(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if config.debug {
                print("[Heardock] network: \(error.localizedDescription)")
            }
            throw HeardockError(code: .network)
        }
        guard let http = response as? HTTPURLResponse else {
            throw HeardockError(code: .invalidResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            let error = HeardockError.from(status: http.statusCode, data: data)
            if config.debug {
                print("[Heardock] \(http.statusCode) \(error.serverMessage ?? "")")
            }
            throw error
        }
        return data
    }
}
