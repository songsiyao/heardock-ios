import HeardockCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// How the host app presents the feedback form.
///
/// Both modes draw the same form. `.page` is the default: a full-screen page
/// pushed onto a `NavigationStack`. `.sheet` adds the modal grabber and a
/// close button for hosts that present it with `.sheet`.
public enum HeardockPresentation: Sendable {
    case page
    case sheet
}

/// The bundled feedback form.
///
/// The full-screen page is the default and expects a `NavigationStack` (for
/// the title, back button and the history shortcut):
///
/// ```swift
/// NavigationLink { HeardockFeedbackView() } label: { Text("Send feedback") }
/// ```
///
/// Pass `presentation: .sheet` when presenting it with `.sheet` instead.
@MainActor
public struct HeardockFeedbackView: View {
    @ObservedObject private var client: Heardock
    private let theme: HeardockTheme
    private let customStrings: HeardockStrings?
    private let locale: Locale
    private let presentation: HeardockPresentation

    private var strings: HeardockStrings {
        customStrings ?? .resolved(
            localeIdentifier: client.config?.locale ?? locale.identifier,
            overrides: client.config?.strings ?? [:]
        )
    }

    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var category: FeedbackCategory?
    @State private var landing: Landing = .undecided
    @State private var isSending = false
    @State private var errorText: String?
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var composeFromHistory = false
    @FocusState private var editorFocused: Bool

    /// Which screen the entry point opens with. A device with notes (including
    /// notes still queued on it) lands on its list; a device with none lands
    /// on the form; a failed read with nothing cached shows the error.
    private enum Landing {
        case undecided
        case compose
        case history
        case failed
    }

    private let limit = 2000

    public init(
        client: Heardock? = nil,
        theme: HeardockTheme = .standard,
        strings: HeardockStrings? = nil,
        presentation: HeardockPresentation = .page,
        locale: Locale = .current
    ) {
        _client = ObservedObject(wrappedValue: client ?? .shared)
        self.theme = theme
        self.customStrings = strings
        self.locale = locale
        self.presentation = presentation
    }

    public var body: some View {
        Group {
            switch landing {
            case .undecided:
                landingLoading
            case .history:
                HeardockHistoryView(client: client, theme: theme, strings: strings)
            case .compose:
                form
            case .failed:
                failedLanding
            }
        }
        .background(theme.background.ignoresSafeArea())
        .heardockNavigationChrome(background: theme.background)
        .navigationTitle(navigationTitle)
        .navigationBarBackButtonHidden(landing == .compose && composeFromHistory)
        .overlay(alignment: .top) { toastOverlay }
        .toolbar {
            if presentation == .page {
                if landing == .compose && composeFromHistory {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            landing = .history
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel(strings.historyTitle)
                    }
                    #endif
                }
                ToolbarItem(placement: .primaryAction) {
                    if landing == .history {
                        Button {
                            startCompose()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel(strings.send)
                    } else if landing == .compose {
                        NavigationLink {
                            HeardockHistoryView(client: client, theme: theme, strings: strings)
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .accessibilityLabel(strings.historyTitle)
                    }
                }
            }
        }
        .task { await decideLanding() }
        .onDisappear { toastTask?.cancel() }
    }

    private var navigationTitle: String {
        guard presentation == .page else { return "" }
        return landing == .history ? strings.historyTitle : strings.navigationTitle
    }

    private var landingLoading: some View {
        VStack(spacing: 12) {
            ProgressView().tint(theme.accent)
            Text(strings.loading)
                .font(.system(size: 12))
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Lands on the list whenever this device has notes — cached server rows
    /// and notes still in the offline queue both count. A failed read with no
    /// cached rows shows the error instead of pretending the device is new.
    /// Sheets keep the form as their entry point because their close button
    /// lives in the form header.
    private func decideLanding() async {
        guard landing == .undecided else { return }
        await client.flushQueue()
        guard presentation == .page else {
            landing = .compose
            return
        }
        await client.refreshHistory()
        landing = resolvedLanding()
    }

    private func resolvedLanding() -> Landing {
        if !client.threads.isEmpty { return .history }
        if client.historyError != nil { return .failed }
        return .compose
    }

    private func retryLanding() {
        landing = .undecided
        Task { @MainActor in await decideLanding() }
    }

    private var failedLanding: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(theme.inkSecondary)
                .frame(width: 72, height: 72)
                .background(theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(spacing: 6) {
                Text(strings.errorTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text(client.historyError.map { strings.readErrorMessage(for: $0) }
                     ?? strings.loadMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Button(strings.retry) { retryLanding() }
                .buttonStyle(HeardockSecondaryButtonStyle(theme: theme))
                .frame(maxWidth: 220)
            Button(strings.send) {
                reset()
                landing = .compose
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.inkSecondary)
            .frame(minHeight: 44)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(22)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(theme.line))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { toast = text }
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: text)
        #endif
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { toast = nil }
        }
    }

    private func startCompose() {
        reset()
        composeFromHistory = true
        landing = .compose
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !trimmedMessage.isEmpty && category != nil && !isSending
    }

    private var form: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if presentation == .sheet {
                            grabber
                        }
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(strings.title)
                                    .font(.system(size: theme.titleSize, weight: .heavy))
                                    .tracking(theme.titleTracking)
                                    .foregroundStyle(theme.ink)
                                Text(strings.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if presentation == .sheet {
                                closeButton
                            }
                        }

                        categorySection
                        messageSection
                            .id("heardock-message")
                    }
                    .padding(22)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: editorFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("heardock-message", anchor: .top)
                    }
                }
            }
            footer
        }
    }

    /// Same four kinds the Flutter feedback sheet offers, and like that sheet a
    /// note cannot be sent until one is picked. `.other` stays a wire fallback
    /// only, so it is never shown as a choice.
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(strings.categoryHeading)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text(strings.requiredLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(FeedbackCategory.selectable) { category in
                    categoryChip(category)
                }
            }
        }
    }

    /// Four equal columns in one row, icon above label — the same square tile
    /// the Flutter sheet draws, instead of a wrapping grid.
    private func categoryChip(_ kind: FeedbackCategory) -> some View {
        let selected = category == kind
        return Button {
            category = kind
        } label: {
            VStack(spacing: 4) {
                Image(systemName: heardockSymbol(for: kind))
                    .font(.system(size: 18, weight: .regular))
                Text(strings.categoryLabel(kind))
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selected ? theme.accent : theme.inkSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(selected ? theme.accentSoft : theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .stroke(selected ? theme.accent : theme.line, lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Modal chrome shared by both phases when presented as a sheet.
    private var grabber: some View {
        Capsule()
            .fill(theme.line)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .accessibilityHidden(true)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.inkSecondary)
                .frame(width: 30, height: 30)
                .background(theme.surface)
                .clipShape(Circle())
                .overlay(Circle().stroke(theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(strings.closeLabel)
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(strings.messageLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text("\(message.count)/\(limit)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(message.count >= limit ? theme.danger : theme.muted)
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $message)
                    .focused($editorFocused)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: 160)
                    .background(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .stroke(editorFocused ? theme.accent : theme.line,
                                    lineWidth: editorFocused ? 1.6 : 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
                if message.isEmpty {
                    Text(strings.messagePlaceholder)
                        .font(.system(size: 15))
                        .foregroundStyle(theme.muted.opacity(0.75))
                        .padding(.horizontal, 17)
                        .padding(.top, 18)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: message) { _, newValue in
                if newValue.count > limit {
                    message = String(newValue.prefix(limit))
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if let errorText {
                Text(errorText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.danger)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            if client.pendingCount > 0 && !editorFocused {
                Text(client.pendingCount == 1
                     ? strings.waitingOne
                     : String(format: strings.waitingManyFormat, client.pendingCount))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity)
            }
            if !editorFocused {
                VStack(spacing: 1) {
                    Text(strings.privacyPrimary)
                    Text(strings.privacySecondary)
                }
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            Button {
                send()
            } label: {
                if isSending {
                    ProgressView().tint(theme.ink)
                } else {
                    Text(strings.send)
                }
            }
            .buttonStyle(HeardockPrimaryButtonStyle(theme: theme))
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.55)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(theme.background)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.line).frame(height: 1)
        }
    }

    private func send() {
        let text = trimmedMessage
        guard !text.isEmpty, category != nil, !isSending else { return }
        editorFocused = false
        isSending = true
        errorText = nil
        Task { @MainActor in
            do {
                let result = try await client.submit(
                    message: text,
                    category: category ?? .other
                )
                isSending = false
                // No interstitial page: go straight back to the list. The new
                // row is the durable confirmation; the toast is the short one.
                if presentation == .sheet {
                    dismiss()
                    return
                }
                reset()
                composeFromHistory = false
                landing = .history
                showToast(result.queued ? strings.queuedToast : strings.sentToast)
            } catch let error as HeardockError {
                isSending = false
                errorText = strings.sendErrorMessage(for: error)
            } catch {
                isSending = false
                errorText = strings.genericSendMessage
            }
        }
    }

    private func reset() {
        message = ""
        category = nil
        errorText = nil
        isSending = false
    }
}
