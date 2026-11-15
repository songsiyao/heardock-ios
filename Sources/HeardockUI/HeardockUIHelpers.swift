import HeardockCore
import SwiftUI

// MARK: - Buttons

struct HeardockPrimaryButtonStyle: ButtonStyle {
    let theme: HeardockTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}

struct HeardockSecondaryButtonStyle: ButtonStyle {
    let theme: HeardockTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(theme.line)
            )
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .opacity(configuration.isPressed ? 0.68 : 1)
    }
}

// MARK: - Categories & status

func heardockSymbol(for category: FeedbackCategory) -> String {
    switch category {
    case .bug: return "ant"
    case .idea: return "lightbulb"
    case .question: return "questionmark"
    case .praise: return "heart"
    case .other: return "ellipsis"
    }
}

func heardockStatusForeground(_ status: String, theme: HeardockTheme) -> Color {
    switch status {
    case "done": return theme.success
    case "closed", "spam": return theme.muted
    case "queued": return theme.inkSecondary
    default: return theme.inkSecondary
    }
}

func heardockStatusBackground(_ status: String, theme: HeardockTheme) -> Color {
    switch status {
    case "new": return theme.accentSoft
    case "triaged", "planned", "in_progress": return theme.accentSoft.opacity(0.7)
    case "done": return theme.successSoft
    case "closed", "spam": return theme.background
    case "queued": return theme.accentSoft.opacity(0.65)
    default: return theme.accentSoft
    }
}

func heardockRelativeDate(_ date: Date?, strings: HeardockStrings) -> String {
    guard let date else { return "" }
    let interval = max(0, Date().timeIntervalSince(date))
    if interval < 60 { return strings.justNow }
    if interval < 3_600 { return String(format: strings.minutesAgoFormat, Int(interval / 60)) }
    if interval < 86_400 { return String(format: strings.hoursAgoFormat, Int(interval / 3_600)) }
    if interval < 604_800 { return String(format: strings.daysAgoFormat, Int(interval / 86_400)) }
    return date.formatted(.dateTime.month(.abbreviated).day())
}

struct HeardockStatusPill: View {
    let status: String
    let theme: HeardockTheme
    let strings: HeardockStrings

    var body: some View {
        Text(strings.statusLabel(status))
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(heardockStatusForeground(status, theme: theme))
            .padding(.horizontal, 8)
            .frame(minHeight: 22)
            .background(heardockStatusBackground(status, theme: theme))
            .clipShape(Capsule())
    }
}
