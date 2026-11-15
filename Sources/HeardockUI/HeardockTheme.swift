import SwiftUI

/// Visual tokens for the bundled feedback screens.
///
/// The defaults are a neutral indigo. Host apps can pass their own palette so
/// the screens feel native to their product.
public struct HeardockTheme {
    public var accent: Color
    public var accentSoft: Color
    public var background: Color
    public var surface: Color
    public var ink: Color
    public var inkSecondary: Color
    public var muted: Color
    public var line: Color
    public var success: Color
    public var successSoft: Color
    public var danger: Color
    public var cornerRadius: CGFloat
    public var titleSize: CGFloat
    public var titleTracking: CGFloat

    public init(
        accent: Color,
        accentSoft: Color,
        background: Color,
        surface: Color = .white,
        ink: Color,
        inkSecondary: Color,
        muted: Color,
        line: Color,
        success: Color,
        successSoft: Color,
        danger: Color,
        cornerRadius: CGFloat = 18,
        titleSize: CGFloat = 25,
        titleTracking: CGFloat = -0.8
    ) {
        self.accent = accent
        self.accentSoft = accentSoft
        self.background = background
        self.surface = surface
        self.ink = ink
        self.inkSecondary = inkSecondary
        self.muted = muted
        self.line = line
        self.success = success
        self.successSoft = successSoft
        self.danger = danger
        self.cornerRadius = cornerRadius
        self.titleSize = titleSize
        self.titleTracking = titleTracking
    }

    public static let standard = HeardockTheme(
        accent: Color(red: 0.388, green: 0.400, blue: 0.945),
        accentSoft: Color(red: 0.929, green: 0.933, blue: 1.0),
        background: Color(red: 0.976, green: 0.976, blue: 0.988),
        ink: Color(red: 0.067, green: 0.094, blue: 0.153),
        inkSecondary: Color(red: 0.216, green: 0.255, blue: 0.318),
        muted: Color(red: 0.420, green: 0.451, blue: 0.502),
        line: Color(red: 0.902, green: 0.910, blue: 0.941),
        success: Color(red: 0.094, green: 0.463, blue: 0.341),
        successSoft: Color(red: 0.918, green: 0.976, blue: 0.949),
        danger: Color(red: 0.741, green: 0.286, blue: 0.224)
    )
}
