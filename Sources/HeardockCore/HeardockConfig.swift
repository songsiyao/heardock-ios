import Foundation

/// Per-field switches for automatic context collection.
///
/// App version and build number are core context and are always collected.
/// Everything else can be disabled for privacy-sensitive apps.
public struct HeardockCollectOptions {
    public var device: Bool
    public var locale: Bool
    public var screen: Bool

    public init(device: Bool = true, locale: Bool = true, screen: Bool = true) {
        self.device = device
        self.locale = locale
        self.screen = screen
    }
}

/// Immutable configuration passed once to `Heardock.configure`.
public struct HeardockConfig {
    /// Publishable key. Safe to embed in a client binary.
    public var publicKey: String

    /// Base URL of the Heardock deployment, without a trailing `/v1`.
    public var baseURL: URL

    public var collect: HeardockCollectOptions

    /// Force a locale (`en`, `zh-Hans`, …). Nil follows the device.
    public var locale: String?

    /// Caller-provided copy overrides using the shared Heardock string keys.
    public var strings: [String: String]

    /// Print SDK diagnostics with `print` in debug builds.
    public var debug: Bool

    /// Maximum number of notes kept in the offline queue.
    public var maxQueued: Int

    public var requestTimeout: TimeInterval

    /// Whether a 5xx or 429 reply keeps the note for a later retry.
    ///
    /// The Flutter SDK queues these; set `false` when the host app would
    /// rather show the failure than promise a delivery the service is not
    /// currently able to accept.
    public var queueServerErrors: Bool

    /// UserDefaults suite used for the device token and the offline queue.
    /// Nil uses `UserDefaults.standard`.
    public var suiteName: String?

    /// Optional session injection for tests or a shared connection pool.
    public var session: URLSession?

    public init(
        publicKey: String,
        baseURL: URL = URL(string: "https://heardock.com")!,
        collect: HeardockCollectOptions = .init(),
        locale: String? = nil,
        strings: [String: String] = [:],
        debug: Bool = false,
        maxQueued: Int = 20,
        requestTimeout: TimeInterval = 15,
        queueServerErrors: Bool = true,
        suiteName: String? = nil,
        session: URLSession? = nil
    ) {
        let trimmed = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(!trimmed.isEmpty, "A publishable key is required (hd_pub_…).")
        precondition(baseURL.scheme != nil && baseURL.host != nil, "baseURL must be absolute.")
        precondition(maxQueued >= 1, "maxQueued must be at least 1.")
        self.publicKey = trimmed
        self.baseURL = baseURL
        self.collect = collect
        self.locale = locale
        self.strings = strings
        self.debug = debug
        self.maxQueued = maxQueued
        self.requestTimeout = requestTimeout
        self.queueServerErrors = queueServerErrors
        self.suiteName = suiteName
        self.session = session
    }
}
