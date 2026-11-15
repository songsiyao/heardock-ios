import Foundation
import HeardockCore

/// Copy used by the bundled screens.
///
/// English and Simplified Chinese are built in. Pass a custom value to change
/// the team name or to override individual lines.
public struct HeardockStrings {
    public var teamName: String

    public var navigationTitle: String
    public var closeLabel: String
    public var title: String
    public var subtitle: String
    public var categoryHeading: String
    public var requiredLabel: String
    public var messageLabel: String
    public var messagePlaceholder: String
    public var privacyPrimary: String
    public var privacySecondary: String
    public var send: String

    public var successTitle: String
    public var successBody: String
    public var queuedTitle: String
    public var queuedBody: String
    public var queuedBadge: String
    /// Short confirmation shown over the list after a note is sent.
    public var sentToast: String
    /// Short confirmation shown over the list after a note is queued.
    public var queuedToast: String
    public var done: String
    public var sendAnother: String
    public var seeFeedback: String

    public var historyTitle: String
    public var emptyTitle: String
    public var emptyBody: String
    public var errorTitle: String
    public var retry: String
    public var loading: String

    public var threadTitle: String
    public var noReplyTitle: String
    public var noReplyBody: String
    public var checkingReplies: String
    public var systemLabel: String
    public var remove: String
    public var removeTitle: String
    public var removeBody: String
    public var removeAction: String
    public var keep: String

    public var justNow: String
    public var minutesAgoFormat: String
    public var hoursAgoFormat: String
    public var daysAgoFormat: String
    public var statusSent: String
    public var statusRead: String
    public var statusPlanned: String
    public var statusInProgress: String
    public var statusDone: String
    public var statusClosed: String

    public var waitingOne: String
    public var waitingManyFormat: String
    public var replyOne: String
    public var replyManyFormat: String

    public var categoryBug: String
    public var categoryIdea: String
    public var categoryQuestion: String
    public var categoryPraise: String
    public var categoryOther: String

    public var emptyMessage: String
    public var invalidKeyMessage: String
    public var rateLimitedMessage: String
    public var payloadTooLargeMessage: String
    public var invalidRequestMessage: String
    public var networkMessage: String
    public var genericSendMessage: String
    public var saveFailedMessage: String
    public var loadMessage: String
    public var notFoundMessage: String
    public var threadLoadMessage: String
    public var removeFailedMessage: String

    public func statusLabel(_ status: String) -> String {
        switch status {
        case "new": return statusSent
        case "triaged": return statusRead
        case "planned": return statusPlanned
        case "in_progress": return statusInProgress
        case "done": return statusDone
        case "closed", "spam": return statusClosed
        case "queued": return queuedBadge
        default: return statusSent
        }
    }

    public func categoryLabel(_ category: FeedbackCategory) -> String {
        switch category {
        case .bug: return categoryBug
        case .idea: return categoryIdea
        case .question: return categoryQuestion
        case .praise: return categoryPraise
        case .other: return categoryOther
        }
    }

    public func sendErrorMessage(for error: HeardockError) -> String {
        switch error.code {
        case .rateLimited: return rateLimitedMessage
        case .payloadTooLarge: return payloadTooLargeMessage
        case .invalidRequest: return invalidRequestMessage
        case .invalidKey, .invalidDevice: return invalidKeyMessage
        case .network, .invalidResponse: return networkMessage
        case .notConfigured: return genericSendMessage
        case .server, .notFound: return genericSendMessage
        }
    }

    public func readErrorMessage(for error: HeardockError) -> String {
        switch error.code {
        case .notFound: return notFoundMessage
        case .network, .invalidResponse: return networkMessage
        default: return loadMessage
        }
    }

    public mutating func applyOverrides(_ overrides: [String: String]) {
        for (key, value) in overrides {
            switch key {
            case "title": title = value
            case "subtitle": subtitle = value
            case "categoryHeading": categoryHeading = value
            case "requiredLabel": requiredLabel = value
            case "messageLabel": messageLabel = value
            case "messagePlaceholder": messagePlaceholder = value
            case "privacyTemplate":
                privacyPrimary = value
                    .replacingOccurrences(of: "{app}", with: teamName)
                    .replacingOccurrences(of: "{brand}", with: "Heardock")
            case "send": send = value
            case "close": closeLabel = value
            case "successTitle": successTitle = value
            case "successBody": successBody = value
            case "sendAnother": sendAnother = value
            case "emptyMessage": emptyMessage = value
            case "invalidKey": invalidKeyMessage = value
            case "rateLimited": rateLimitedMessage = value
            case "payloadTooLarge": payloadTooLargeMessage = value
            case "invalidRequest": invalidRequestMessage = value
            case "networkError": networkMessage = value
            case "genericError": genericSendMessage = value
            case "categoryBug": categoryBug = value
            case "categoryIdea": categoryIdea = value
            case "categoryQuestion": categoryQuestion = value
            case "categoryPraise": categoryPraise = value
            case "categoryOther": categoryOther = value
            case "queuedTitle": queuedTitle = value
            case "queuedBody": queuedBody = value
            case "queuedBadge": queuedBadge = value
            case "sentToast": sentToast = value
            case "queuedToast": queuedToast = value
            case "done": done = value
            case "retry": retry = value
            case "centerTitle":
                navigationTitle = value
                historyTitle = value
            case "centerEmptyTitle": emptyTitle = value
            case "centerEmptyBody": emptyBody = value
            case "noReplies": noReplyTitle = value
            case "noRepliesBody": noReplyBody = value
            case "loadingReplies": checkingReplies = value
            case "loadError": errorTitle = value
            case "loadErrorBody": loadMessage = value
            case "deleteFeedback", "deleteTitle": removeTitle = value
            case "deleteBody": removeBody = value
            case "deleteAction": removeAction = value
            case "deleteError": removeFailedMessage = value
            case "cancel": keep = value
            case "sentLabel": statusSent = value
            case "repliedLabel": statusRead = value
            case "replyCountTemplate": replyManyFormat = value.replacingOccurrences(of: "{n}", with: "%d")
            case "justNow": justNow = value
            case "minutesAgoTemplate": minutesAgoFormat = value.replacingOccurrences(of: "{n}", with: "%d")
            case "hoursAgoTemplate": hoursAgoFormat = value.replacingOccurrences(of: "{n}", with: "%d")
            case "daysAgoTemplate": daysAgoFormat = value.replacingOccurrences(of: "{n}", with: "%d")
            default: break
            }
        }
    }

    public static func english(teamName: String = "team") -> HeardockStrings {
        HeardockStrings(
            teamName: teamName,
            navigationTitle: "Send feedback",
            closeLabel: "Close",
            title: "Tell us what's\non your mind.",
            subtitle: "Bugs, ideas, or anything that felt off — we read every note.",
            categoryHeading: "What kind of feedback?",
            requiredLabel: "Required",
            messageLabel: "Your message",
            messagePlaceholder: "What happened? What did you expect?",
            privacyPrimary: "Private — only the \(teamName) reads this.",
            privacySecondary: "Your note comes with your app version and phone model.",
            send: "Send feedback",
            successTitle: "Feedback sent",
            successBody: "Thanks — we read every note. If there's more to figure out, our reply will show up under Your feedback.",
            queuedTitle: "Saved on this iPhone",
            queuedBody: "We'll send this as soon as you're back online.",
            queuedBadge: "Queued",
            sentToast: "Feedback sent",
            queuedToast: "Saved — we'll send it when you're online.",
            done: "Done",
            sendAnother: "Send another",
            seeFeedback: "See your feedback",
            historyTitle: "Your feedback",
            emptyTitle: "No notes yet",
            emptyBody: "When you send feedback, it will show up here, along with any reply from us.",
            errorTitle: "Couldn't load your notes",
            retry: "Try again",
            loading: "Loading your feedback…",
            threadTitle: "Your note",
            noReplyTitle: "No reply yet",
            noReplyBody: "We read every note. If we need anything from you, we'll reply here.",
            checkingReplies: "Checking for replies…",
            systemLabel: "Update",
            remove: "Remove from this iPhone",
            removeTitle: "Remove this note?",
            removeBody: "It will no longer appear in your feedback on this iPhone.",
            removeAction: "Remove",
            keep: "Keep it",
            justNow: "Just now",
            minutesAgoFormat: "%dm ago",
            hoursAgoFormat: "%dh ago",
            daysAgoFormat: "%dd ago",
            statusSent: "Sent",
            statusRead: "Read",
            statusPlanned: "Planned",
            statusInProgress: "In progress",
            statusDone: "Done",
            statusClosed: "Closed",
            waitingOne: "1 note is waiting to send.",
            waitingManyFormat: "%d notes are waiting to send.",
            replyOne: "1 reply",
            replyManyFormat: "%d replies",
            categoryBug: "Bug",
            categoryIdea: "Idea",
            categoryQuestion: "Question",
            categoryPraise: "Praise",
            categoryOther: "Other",
            emptyMessage: "Write a few words before sending.",
            invalidKeyMessage: "This app is not set up for feedback right now.",
            rateLimitedMessage: "Too many notes right now. Try again in a minute.",
            payloadTooLargeMessage: "That note is a little too long.",
            invalidRequestMessage: "Something in the note needs a quick edit. Please try again.",
            networkMessage: "Check your connection and try again.",
            genericSendMessage: "We couldn't send this right now. Please try again in a moment.",
            saveFailedMessage: "We couldn't save this note on your iPhone. Please try again.",
            loadMessage: "We couldn't load this right now. Please try again.",
            notFoundMessage: "This note is no longer available.",
            threadLoadMessage: "We couldn't load this note. Please try again.",
            removeFailedMessage: "We couldn't remove this note. Please try again."
        )
    }

    public static func simplifiedChinese(teamName: String = "团队") -> HeardockStrings {
        HeardockStrings(
            teamName: teamName,
            navigationTitle: "发送反馈",
            closeLabel: "关闭",
            title: "想告诉我们\n什么？",
            subtitle: "问题、想法，或任何不太对劲的地方——每条都会读。",
            categoryHeading: "这是哪类反馈？",
            requiredLabel: "必填",
            messageLabel: "你的留言",
            messagePlaceholder: "发生了什么？你期待怎样的结果？",
            privacyPrimary: "私密——只有\(teamName)能读到。",
            privacySecondary: "留言会带上 App 版本和手机型号，方便我们定位。",
            send: "发送反馈",
            successTitle: "已发送",
            successBody: "谢谢——每条反馈我们都会读。如果需要进一步确认，回复会显示在「你的反馈」里。",
            queuedTitle: "已保存在这台 iPhone",
            queuedBody: "恢复网络后会自动发送。",
            queuedBadge: "等待网络",
            sentToast: "已发送",
            queuedToast: "已保存在本机，联网后自动发送。",
            done: "完成",
            sendAnother: "再写一条",
            seeFeedback: "查看你的反馈",
            historyTitle: "你的反馈",
            emptyTitle: "还没有留言",
            emptyBody: "你发送的反馈会显示在这里，也会显示我们的回复。",
            errorTitle: "没能加载你的留言",
            retry: "重试",
            loading: "正在加载…",
            threadTitle: "你的留言",
            noReplyTitle: "还没有回复",
            noReplyBody: "每条我们都会读。如果需要了解更多，会在这里回复。",
            checkingReplies: "正在检查回复…",
            systemLabel: "更新",
            remove: "从这台 iPhone 移除",
            removeTitle: "移除这条留言？",
            removeBody: "它不会再显示在这台 iPhone 的反馈里。",
            removeAction: "移除",
            keep: "保留",
            justNow: "刚刚",
            minutesAgoFormat: "%d 分钟前",
            hoursAgoFormat: "%d 小时前",
            daysAgoFormat: "%d 天前",
            statusSent: "已发送",
            statusRead: "已读",
            statusPlanned: "已计划",
            statusInProgress: "处理中",
            statusDone: "已完成",
            statusClosed: "已关闭",
            waitingOne: "1 条留言等待发送。",
            waitingManyFormat: "%d 条留言等待发送。",
            replyOne: "1 条回复",
            replyManyFormat: "%d 条回复",
            categoryBug: "问题",
            categoryIdea: "想法",
            categoryQuestion: "疑问",
            categoryPraise: "称赞",
            categoryOther: "其他",
            emptyMessage: "先写几个字再发送。",
            invalidKeyMessage: "这个 App 暂时无法接收反馈。",
            rateLimitedMessage: "留言太频繁了，请一分钟后再试。",
            payloadTooLargeMessage: "这条留言有点长。",
            invalidRequestMessage: "留言里有内容需要修改，请再试一次。",
            networkMessage: "检查一下网络，再试一次。",
            genericSendMessage: "现在没能发送，请稍后再试。",
            saveFailedMessage: "没能保存到这台 iPhone，请再试一次。",
            loadMessage: "现在没能加载，请稍后再试。",
            notFoundMessage: "这条留言已经不在了。",
            threadLoadMessage: "没能加载这条留言，请再试一次。",
            removeFailedMessage: "没能移除这条留言，请再试一次。"
        )
    }

    /// Picks Chinese for zh-* locales, English otherwise.
    public static func resolved(
        teamName: String? = nil,
        locale: Locale = .current,
        overrides: [String: String] = [:]
    ) -> HeardockStrings {
        let language = locale.language.languageCode?.identifier ?? "en"
        var strings = language == "zh"
            ? simplifiedChinese(teamName: teamName ?? "团队")
            : english(teamName: teamName ?? "team")
        strings.applyOverrides(overrides)
        return strings
    }

    public static func resolved(
        localeIdentifier: String?,
        overrides: [String: String] = [:]
    ) -> HeardockStrings {
        resolved(
            locale: localeIdentifier.map { Locale(identifier: $0) } ?? .current,
            overrides: overrides
        )
    }
}
