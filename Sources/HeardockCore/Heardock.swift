import Combine
import Foundation

/// Headless entry point: configuration, context capture, submission, the
/// offline queue and the device's own thread list. It renders nothing; use
/// `HeardockUI` for the bundled SwiftUI screens or build your own form.
///
/// ```swift
/// Heardock.shared.configure(HeardockConfig(publicKey: "hd_pub_…"))
/// let result = try await Heardock.shared.submit(message: "Export freezes")
/// if result.queued { /* stored on the device and retried later */ }
/// ```
@MainActor
public final class Heardock: ObservableObject {
    public static let shared = Heardock()

    /// How many notes are waiting on the device.
    @Published public private(set) var pendingCount = 0

    /// Notes submitted by this device, newest first.
    ///
    /// This is the server's answer, persisted between launches so the entry
    /// point still opens the list while offline. Queued notes live in
    /// ``pendingNotes``; use ``threads`` for the merged list the UI shows.
    @Published public private(set) var history: [HeardockThread] = []

    /// Notes still waiting in the offline queue, newest first.
    @Published public private(set) var pendingNotes: [HeardockThread] = []

    /// The rows the list renders: queued notes on top of the server history.
    public var threads: [HeardockThread] { pendingNotes + history }

    @Published public private(set) var isLoadingHistory = false
    @Published public private(set) var historyError: HeardockError?
    @Published public private(set) var localizationRevision = 0

    public private(set) var config: HeardockConfig?
    public private(set) var isConfigured = false

    private var api: HeardockAPI?
    private var defaults: UserDefaults = .standard
    private var deviceToken = ""
    private var queue: [PendingSubmission] = []
    private var isFlushing = false
    private var user: HeardockUser?
    private var screen: String?
    private var metadata: [String: String] = [:]
    private let collector = ContextCollector()

    private static let maximumAttempts = 5
    private static let retryDelays: [TimeInterval] = [1, 5, 30, 120, 600]

    public init() {}

    public func configure(_ config: HeardockConfig) {
        self.config = config
        defaults = config.suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        deviceToken = DeviceIdentity.token(defaults: defaults, projectKey: config.publicKey)
        api = HeardockAPI(config: config, deviceToken: deviceToken)
        queue = Self.loadQueue(defaults: defaults, key: Self.storageKey(for: config.publicKey))
        history = Self.loadHistory(defaults: defaults, key: Self.historyKey(for: config.publicKey))
        pendingCount = queue.count
        rebuildPendingNotes()
        isConfigured = true
        Task { await flushQueue() }
    }

    /// Replaces localization configuration and refreshes observed SwiftUI views.
    public func updateLocalization(locale: String? = nil, strings: [String: String] = [:]) {
        config?.locale = locale
        config?.strings = strings
        localizationRevision += 1
    }

    // MARK: Identity & context

    /// Attaches an optional identity to notes submitted after this call.
    /// Nothing is collected implicitly: only the fields you pass here are sent.
    public func identify(id: String? = nil, email: String? = nil, name: String? = nil) {
        user = HeardockUser(id: id, email: email, name: name)
    }

    public func clearIdentity() {
        user = nil
    }

    /// Sets the current screen (for example after a route change) and extra
    /// metadata. Metadata is merged with previous calls.
    public func setContext(screen: String? = nil, metadata: [String: String] = [:]) {
        if let screen { self.screen = screen }
        self.metadata.merge(metadata) { _, new in new }
    }

    public func clearContext() {
        screen = nil
        metadata.removeAll()
    }

    /// Collects the reproduction context without submitting anything.
    public func captureContext(screen: String? = nil) -> HeardockContext? {
        guard let config else { return nil }
        return collector.collect(config: config, screen: screen ?? self.screen)
    }

    // MARK: Submission

    /// Submits feedback without UI.
    ///
    /// A note that cannot reach the service is stored on the device and
    /// returned with `queued == true`. Errors that will never succeed throw
    /// `HeardockError`.
    @discardableResult
    public func submit(
        message: String,
        category: FeedbackCategory = .other,
        email: String? = nil,
        metadata: [String: String] = [:]
    ) async throws -> HeardockResult {
        guard let config, let api else {
            throw HeardockError(code: .notConfigured)
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HeardockError(code: .invalidRequest)
        }

        var draftMetadata = self.metadata
        draftMetadata.merge(metadata) { _, new in new }
        var draftUser = user
        if let email, !email.isEmpty {
            draftUser = HeardockUser(id: draftUser?.id, email: email, name: draftUser?.name)
        }

        let draft = HeardockDraft(
            message: String(trimmed.prefix(2000)),
            category: category,
            user: (draftUser?.isEmpty ?? true) ? nil : draftUser,
            context: collector.collect(config: config, screen: screen),
            metadata: draftMetadata
        )
        let idempotencyKey = UUID().uuidString.lowercased()

        do {
            return try await api.submit(draft, idempotencyKey: idempotencyKey)
        } catch let error as HeardockError {
            if canQueue(error) {
                enqueue(PendingSubmission(
                    id: idempotencyKey,
                    draft: draft,
                    createdAt: Date(),
                    attempts: 0,
                    nextAttemptAt: Date()
                ))
                return HeardockResult(queuedId: idempotencyKey)
            }
            throw error
        }
    }

    /// Retries pending submissions now and reports what happened.
    @discardableResult
    public func flushQueue() async -> HeardockQueueReport {
        guard !isFlushing, !queue.isEmpty, let api else {
            return HeardockQueueReport(pending: queue.count)
        }
        isFlushing = true
        defer { isFlushing = false }

        var remaining: [PendingSubmission] = []
        var sent = 0
        var dropped = 0
        let now = Date()

        for item in queue {
            guard item.nextAttemptAt <= now else {
                remaining.append(item)
                continue
            }
            do {
                _ = try await api.submit(item.draft, idempotencyKey: item.id)
                sent += 1
            } catch let error as HeardockError {
                // A note already in the queue is retried on any retryable
                // failure; `queueServerErrors` only decides whether a *new*
                // submission is queued, never whether a saved one is dropped.
                if error.retryable, let retried = retry(item, after: error) {
                    remaining.append(retried)
                } else {
                    dropped += 1
                }
            } catch {
                if let retried = retry(item, after: nil) {
                    remaining.append(retried)
                } else {
                    dropped += 1
                }
            }
        }

        queue = remaining
        persistQueue()
        return HeardockQueueReport(sent: sent, dropped: dropped, pending: queue.count)
    }

    // MARK: Threads

    public func refreshHistory() async {
        guard let api else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        do {
            history = try await api.listThreads()
            historyError = nil
            saveHistory()
        } catch let error as HeardockError {
            // Keep the cached snapshot: a failed read must never make a
            // device with notes look new.
            historyError = error
        } catch {
            historyError = HeardockError(code: .invalidResponse)
        }
    }

    public func loadThread(id: String) async throws -> HeardockThread {
        if let queued = pendingNotes.first(where: { $0.id == id }) {
            return queued
        }
        guard let api else { throw HeardockError(code: .notConfigured) }
        return try await api.thread(id: id)
    }

    /// Removes a note from this device's list. The service keeps the note and
    /// its replies for the team (soft delete).
    public func removeThread(id: String) async throws {
        if id.hasPrefix(Self.pendingIdPrefix) {
            let key = String(id.dropFirst(Self.pendingIdPrefix.count))
            queue.removeAll { $0.id == key }
            persistQueue()
            return
        }
        guard let api else { throw HeardockError(code: .notConfigured) }
        try await api.deleteThread(id: id)
        history.removeAll { $0.id == id }
        saveHistory()
    }

    // MARK: Helpers

    private func canQueue(_ error: HeardockError) -> Bool {
        switch error.code {
        case .network:
            return true
        case .server, .rateLimited:
            return config?.queueServerErrors ?? false
        default:
            return false
        }
    }

    private func retry(_ item: PendingSubmission, after error: HeardockError?) -> PendingSubmission? {
        var item = item
        item.attempts += 1
        guard item.attempts < Self.maximumAttempts else { return nil }
        let index = min(item.attempts - 1, Self.retryDelays.count - 1)
        item.nextAttemptAt = Date().addingTimeInterval(Self.retryDelays[index])
        if let error, config?.debug == true {
            print("[Heardock] retry \(item.id) after \(error.code.rawValue)")
        }
        return item
    }

    private func enqueue(_ item: PendingSubmission) {
        guard !queue.contains(where: { $0.id == item.id }) else { return }
        queue.append(item)
        let limit = config?.maxQueued ?? 20
        while queue.count > limit {
            queue.removeFirst()
        }
        persistQueue()
    }

    private func persistQueue() {
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: queueKey)
        }
        pendingCount = queue.count
        rebuildPendingNotes()
    }

    /// Local ids for queued notes. Server ids never start with this prefix.
    private static let pendingIdPrefix = "pending_"

    private func rebuildPendingNotes() {
        pendingNotes = queue
            .map {
                HeardockThread(
                    pendingId: "\(Self.pendingIdPrefix)\($0.id)",
                    draft: $0.draft,
                    createdAt: $0.createdAt
                )
            }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(Array(history.prefix(50))) {
            defaults.set(data, forKey: historyKey)
        }
    }

    private static func loadHistory(defaults: UserDefaults, key: String) -> [HeardockThread] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([HeardockThread].self, from: data)) ?? []
    }

    private var historyKey: String { Self.historyKey(for: config?.publicKey ?? "") }

    private static func historyKey(for projectKey: String) -> String {
        "heardock.history.v1.\(projectKey)"
    }

    private var queueKey: String {
        Self.storageKey(for: config?.publicKey ?? "")
    }

    private static func storageKey(for projectKey: String) -> String {
        "heardock.queue.v1.\(projectKey)"
    }

    private static func loadQueue(defaults: UserDefaults, key: String) -> [PendingSubmission] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PendingSubmission].self, from: data)) ?? []
    }
}

struct PendingSubmission: Codable, Identifiable {
    let id: String
    let draft: HeardockDraft
    let createdAt: Date
    var attempts: Int
    var nextAttemptAt: Date
}
