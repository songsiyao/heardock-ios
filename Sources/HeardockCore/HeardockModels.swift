import Foundation

/// The kind of note a person is leaving.
public enum FeedbackCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case bug
    case idea
    case question
    case praise
    case other

    public var id: String { rawValue }

    /// Kinds a person can pick. `.other` is what the API stores when nothing
    /// was chosen, so the picker never offers it — matching the Flutter sheet.
    public static var selectable: [FeedbackCategory] {
        allCases.filter { $0 != .other }
    }

    public static func wire(_ value: String?) -> FeedbackCategory {
        guard let value, let category = FeedbackCategory(rawValue: value) else { return .other }
        return category
    }
}

/// Optional identity attached to a note. Nothing is collected implicitly.
public struct HeardockUser: Codable, Equatable, Sendable {
    public var id: String?
    public var email: String?
    public var name: String?

    public init(id: String? = nil, email: String? = nil, name: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
    }

    public var isEmpty: Bool {
        (id ?? "").isEmpty && (email ?? "").isEmpty && (name ?? "").isEmpty
    }
}

/// Non-identifying facts that make a note reproducible.
public struct HeardockContext: Codable, Equatable, Sendable {
    public var appVersion: String?
    public var buildNumber: String?
    public var platform: String?
    public var osVersion: String?
    public var device: String?
    public var locale: String?
    public var screen: String?

    public init(
        appVersion: String? = nil,
        buildNumber: String? = nil,
        platform: String? = nil,
        osVersion: String? = nil,
        device: String? = nil,
        locale: String? = nil,
        screen: String? = nil
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.platform = platform
        self.osVersion = osVersion
        self.device = device
        self.locale = locale
        self.screen = screen
    }

    enum CodingKeys: String, CodingKey {
        case appVersion = "app_version"
        case buildNumber = "build_number"
        case platform
        case osVersion = "os_version"
        case device
        case locale
        case screen
    }
}

struct HeardockDraft: Codable {
    let message: String
    let category: FeedbackCategory
    let user: HeardockUser?
    let context: HeardockContext
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case message, category, user, context, metadata
    }

    init(
        message: String,
        category: FeedbackCategory,
        user: HeardockUser?,
        context: HeardockContext,
        metadata: [String: String]
    ) {
        self.message = message
        self.category = category
        self.user = user
        self.context = context
        self.metadata = metadata.isEmpty ? nil : metadata
    }
}

/// The service's acknowledgement for a note.
public struct HeardockResult: Equatable, Sendable {
    public let id: String
    public let status: String
    public let createdAt: Date?
    /// True when the note is still on the device waiting for a network.
    public let queued: Bool

    public init(id: String, status: String, createdAt: Date?, queued: Bool = false) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
        self.queued = queued
    }

    public init(queuedId: String) {
        self.id = queuedId
        self.status = "queued"
        self.createdAt = Date()
        self.queued = true
    }
}

public struct HeardockThreadMessage: Codable, Identifiable, Sendable {
    public let id: String
    public let author: String
    public let body: String
    public let createdAt: Date?

    public var isFromTeam: Bool { author != "system" }

    enum CodingKeys: String, CodingKey {
        case id, author, body
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? "team"
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        createdAt = HeardockDate.parse(try container.decodeIfPresent(String.self, forKey: .createdAt))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(author, forKey: .author)
        try container.encode(body, forKey: .body)
        try container.encodeIfPresent(HeardockDate.string(createdAt), forKey: .createdAt)
    }
}

/// One note plus the team's replies.
public struct HeardockThread: Codable, Identifiable, Sendable {
    public let id: String
    public let category: FeedbackCategory
    public let message: String
    public let status: String
    public let createdAt: Date?
    public let lastReplyAt: Date?
    public let replyCount: Int
    public let context: HeardockContext?
    public let messages: [HeardockThreadMessage]

    /// True while the note still waits in this device's offline queue. Such a
    /// row is local-only: it has no server id and cannot be refreshed.
    public let pending: Bool

    public var hasReply: Bool { replyCount > 0 || lastReplyAt != nil }

    enum CodingKeys: String, CodingKey {
        case id, category, message, status, context, messages, pending
        case createdAt = "created_at"
        case lastReplyAt = "last_reply_at"
        case replyCount = "reply_count"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = FeedbackCategory.wire(try container.decodeIfPresent(String.self, forKey: .category))
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "new"
        createdAt = HeardockDate.parse(try container.decodeIfPresent(String.self, forKey: .createdAt))
        lastReplyAt = HeardockDate.parse(try container.decodeIfPresent(String.self, forKey: .lastReplyAt))
        replyCount = try container.decodeIfPresent(Int.self, forKey: .replyCount) ?? 0
        context = try container.decodeIfPresent(HeardockContext.self, forKey: .context)
        messages = try container.decodeIfPresent([HeardockThreadMessage].self, forKey: .messages) ?? []
        pending = try container.decodeIfPresent(Bool.self, forKey: .pending) ?? false
    }

    init(pendingId: String, draft: HeardockDraft, createdAt: Date) {
        id = pendingId
        category = draft.category
        message = draft.message
        status = "queued"
        self.createdAt = createdAt
        lastReplyAt = nil
        replyCount = 0
        context = draft.context
        messages = []
        pending = true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(category, forKey: .category)
        try container.encode(message, forKey: .message)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(HeardockDate.string(createdAt), forKey: .createdAt)
        try container.encodeIfPresent(HeardockDate.string(lastReplyAt), forKey: .lastReplyAt)
        try container.encode(replyCount, forKey: .replyCount)
        try container.encodeIfPresent(context, forKey: .context)
        try container.encode(messages, forKey: .messages)
        try container.encode(pending, forKey: .pending)
    }
}

struct HeardockThreadEnvelope: Decodable {
    let data: [HeardockThread]
}

/// Outcome of a queue drain.
public struct HeardockQueueReport: Equatable, Sendable {
    public let sent: Int
    public let dropped: Int
    public let pending: Int

    public init(sent: Int = 0, dropped: Int = 0, pending: Int = 0) {
        self.sent = sent
        self.dropped = dropped
        self.pending = pending
    }
}

enum HeardockDate {
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return fractional.date(from: value) ?? plain.date(from: value)
    }

    static func string(_ date: Date?) -> String? {
        date.map { fractional.string(from: $0) }
    }
}
