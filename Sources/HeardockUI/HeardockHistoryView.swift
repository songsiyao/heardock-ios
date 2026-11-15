import HeardockCore
import SwiftUI

/// Notes this device submitted, newest first.
@MainActor
public struct HeardockHistoryView: View {
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

    public init(
        client: Heardock? = nil,
        theme: HeardockTheme = .standard,
        strings: HeardockStrings? = nil,
        locale: Locale = .current
    ) {
        _client = ObservedObject(wrappedValue: client ?? .shared)
        self.theme = theme
        self.customStrings = strings
        self.locale = locale
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if client.isLoadingHistory && client.threads.isEmpty {
                    loading
                } else if client.threads.isEmpty {
                    empty
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(client.threads) { thread in
                            NavigationLink {
                                HeardockThreadView(
                                    thread: thread,
                                    client: client,
                                    theme: theme,
                                    strings: strings
                                )
                            } label: {
                                row(thread)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let error = client.historyError {
                        Text(strings.readErrorMessage(for: error))
                            .font(.system(size: 11))
                            .foregroundStyle(theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(20)
        }
        .refreshable { await client.refreshHistory() }
        .task { await client.refreshHistory() }
        .background(theme.background.ignoresSafeArea())
        .heardockNavigationChrome(background: theme.background)
        .navigationTitle(strings.historyTitle)
        
    }

    private var loading: some View {
        VStack(spacing: 12) {
            ProgressView().tint(theme.accent)
            Text(strings.loading)
                .font(.system(size: 12))
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(theme.ink)
                .frame(width: 68, height: 68)
                .background(theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(spacing: 6) {
                Text(client.historyError == nil ? strings.emptyTitle : strings.errorTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text(client.historyError.map { strings.readErrorMessage(for: $0) } ?? strings.emptyBody)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
            }
            if client.historyError != nil {
                Button(strings.retry) {
                    Task { @MainActor in await client.refreshHistory() }
                }
                .buttonStyle(HeardockSecondaryButtonStyle(theme: theme))
                .frame(maxWidth: 200)
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.line)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func row(_ thread: HeardockThread) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: heardockSymbol(for: thread.category))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.ink)
                .frame(width: 38, height: 38)
                .background(theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(strings.categoryLabel(thread.category))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    HeardockStatusPill(status: thread.status, theme: theme, strings: strings)
                }
                Text(thread.message)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.inkSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 5) {
                    Text(heardockRelativeDate(thread.createdAt, strings: strings))
                    if thread.hasReply {
                        Text("·")
                        Text(thread.replyCount <= 1
                             ? strings.replyOne
                             : String(format: strings.replyManyFormat, thread.replyCount))
                            .foregroundStyle(theme.success)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.muted)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.muted)
                .padding(.top, 4)
        }
        .padding(14)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(theme.line)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
    }
}
