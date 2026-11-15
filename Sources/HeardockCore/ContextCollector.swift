import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Gathers the reproduction context that makes a note actionable.
///
/// Every probe is best-effort: missing values must never prevent someone from
/// sending feedback.
struct ContextCollector {
    func collect(config: HeardockConfig, screen: String?) -> HeardockContext {
        let info = Bundle.main.infoDictionary
        var osVersion: String?
        var device: String?

        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        let current = UIDevice.current
        osVersion = current.systemVersion
        device = hardwareIdentifier()
        #elseif os(macOS)
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        device = hardwareIdentifier()
        #endif

        return HeardockContext(
            appVersion: clip(info?["CFBundleShortVersionString"] as? String, 50),
            buildNumber: clip(info?["CFBundleVersion"] as? String, 50),
            platform: platformName,
            osVersion: clip(osVersion, 80),
            device: config.collect.device ? clip(device, 120) : nil,
            locale: config.collect.locale ? clip(config.locale ?? Locale.current.identifier, 35) : nil,
            screen: config.collect.screen ? clip(screen, 300) : nil
        )
    }

    private var platformName: String {
        #if os(iOS)
        return "ios"
        #elseif os(macOS)
        return "macos"
        #elseif os(tvOS)
        return "tvos"
        #elseif os(watchOS)
        return "watchos"
        #elseif os(visionOS)
        return "visionos"
        #else
        return "unknown"
        #endif
    }

    private func clip(_ value: String?, _ maximum: Int) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return String(value.prefix(maximum))
    }

    private func hardwareIdentifier() -> String? {
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { characters in
                String(validatingUTF8: characters)
            }
        }
        #else
        return nil
        #endif
    }
}
