import Foundation

/// Stable, install-scoped bearer token used to read back this device's notes.
///
/// One token per project (`publicKey`). Generated on first use and stored in
/// UserDefaults; deleting the app loses it, which is the accepted trade-off
/// (there is no account recovery).
enum DeviceIdentity {
    private static let pattern = try! NSRegularExpression(pattern: "^[A-Za-z0-9_-]{43}$")

    static func token(defaults: UserDefaults, projectKey: String) -> String {
        let storageKey = "heardock.device.v1.\(projectKey)"
        if let stored = defaults.string(forKey: storageKey), isValid(stored) {
            return stored
        }
        let generated = generate()
        defaults.set(generated, forKey: storageKey)
        return generated
    }

    static func isValid(_ value: String) -> Bool {
        value.count == 43 && pattern.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
    }

    /// 32 random bytes, base64url without padding (43 chars).
    static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        var generator = SystemRandomNumberGenerator()
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: 0...255, using: &generator)
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
