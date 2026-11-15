import HeardockCore
import SwiftUI

/// One note and the team's replies.
@MainActor
public struct HeardockThreadView: View {
    private let thread: HeardockThread
    @ObservedObject private var client: Heardock
    private let theme: HeardockTheme
    private let customStrings: HeardockStrings?
    private let locale: Locale

    private var strings: HeardockStrings {
        customStrings ?? .resolved(
            localeIdentifier: client.config?.locale ?? locale.identifier,
            overrides: client.config?.strings ?? [:]
        )
    }

    @Environment(\.dismiss) private var dismiss
    @State private var detail: HeardockThread?
    @State private var loadError: String?
    @State private var isLoading = true
    @State private var showRemove = false
    @State private var removeError: String?

    public init(
        thread: HeardockThread,
        client: Heardock? = nil,
        theme: HeardockTheme = .standard,
        strings: HeardockStrings? = nil,
        locale: Locale = .current
    ) {
        self.thread = thread
        _client = ObservedObject(wrappedValue: client ?? .shared)
        self.theme = theme
        self.customStrings = strings
        self.locale = locale
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                noteCard
                replies
                if let removeError {
                    Text(removeError)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.danger)
                        .frame(maxWidth: .infinity)
                }
                Button(strings.remove) { showRemove = true }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(20)
        }
        .background(theme.background.ignoresSafeArea())
        .heardockNavigationChrome(background: theme.background)
        .navigationTitle(strings.threadTitle)
        
        .task { await load() }
        .confirmationDialog(
            strings.removeTitle,
            isPresented: $showRemove,
            titleVisibility: .visible
        ) {
            Button(strings.removeAction, role: .destructive) { remove() }
            Button(strings.keep, role: .cancel) {}
        } message: {
            Text(strings.removeBody)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: heardockSymbol(for: thread.category))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.ink)
                .frame(width: 38, height: 38)
                .background(theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(strings.categoryLabel(thread.category))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text(heardockRelativeDate(thread.createdAt, strings: strings))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.muted)
            }
            Spacer()
            HeardockStatusPill(status: detail?.status ?? thread.status, theme: theme, strings: strings)
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings.threadTitle)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.muted)
                .tracking(0.4)
            Text(detail?.message ?? thread.message)
                .font(.system(size: 14))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(theme.line)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var replies: some View {
        if isLoading && detail == nil {
            HStack(spacing: 8) {
                ProgressView().tint(theme.accent)
                Text(strings.checkingReplies)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        } else if let loadError {
            VStack(spacing: 10) {
                Text(loadError)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
                Button(strings.retry) {
                    Task { @MainActor in await load() }
                }
                .buttonStyle(HeardockSecondaryButtonStyle(theme: theme))
                .frame(maxWidth: 200)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
        } else if let detail, detail.messages.isEmpty {
            VStack(spacing: 5) {
                Text(strings.noReplyTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text(strings.noReplyBody)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .stroke(theme.line)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        } else if let detail {
            VStack(alignment: .leading, spacing: 10) {
                Text(detail.messages.count == 1
                     ? strings.replyOne
                     : String(format: strings.replyManyFormat, detail.messages.count))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.muted)
                    .tracking(0.4)
                ForEach(detail.messages) { message in
                    replyBubble(message)
                }
            }
        }
    }

    private func replyBubble(_ message: HeardockThreadMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.ink)
                .frame(width: 28, height: 28)
                .background(theme.accent)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(message.isFromTeam ? strings.teamName : strings.systemLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text(message.body)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(heardockRelativeDate(message.createdAt, strings: strings))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(message.isFromTeam ? theme.accentSoft.opacity(0.55) : theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func load() async {
        // A queued note lives only on this device; there is nothing to fetch.
        if thread.pending {
            detail = thread
            isLoading = false
            return
        }
        isLoading = true
        loadError = nil
        do {
            detail = try await client.loadThread(id: thread.id)
        } catch let error as HeardockError {
            loadError = strings.readErrorMessage(for: error)
        } catch {
            loadError = strings.threadLoadMessage
        }
        isLoading = false
    }

    private func remove() {
        Task { @MainActor in
            do {
                try await client.removeThread(id: thread.id)
                dismiss()
            } catch {
                removeError = strings.removeFailedMessage
            }
        }
    }
}
