# Heardock iOS SDK

## [Visit Heardock.com](https://heardock.com)

**Every app. Every user. Heard.** One private inbox for feedback from every app and website you ship.

Native Swift packages for collecting private user feedback with Heardock. Includes a headless Core client, SwiftUI feedback UI, context capture, device identity, an offline queue, and caller-provided localization.

## Requirements

- iOS 17+ / macOS 14+
- Swift 5.9+
- Xcode 16+ recommended

## Install with Swift Package Manager

In Xcode, open **File → Add Package Dependencies…** and enter:

```text
https://github.com/songsiyao/heardock-ios.git
```

Select **Up to Next Major Version** from `0.1.0`, then add `HeardockCore` and/or `HeardockUI` to your target.

Or declare it in `Package.swift`:

```swift
.package(
    url: "https://github.com/songsiyao/heardock-ios.git",
    from: "0.1.0"
)
```

## Products

| Product | Purpose |
| --- | --- |
| `HeardockCore` | Headless configuration, context, submission, offline queue, threads, and localization configuration |
| `HeardockUI` | SwiftUI form, feedback history, read-only team replies, themes, and localized copy |

## Quick start

```swift
import HeardockCore
import HeardockUI
import SwiftUI

@main
struct MyApp: App {
    init() {
        Heardock.shared.configure(HeardockConfig(
            publicKey: "hd_pub_your_key",
            baseURL: URL(string: "https://heardock.com")!
        ))
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                NavigationLink("Send feedback") {
                    HeardockFeedbackView()
                }
            }
        }
    }
}
```

The default presentation is a full-screen page inside a `NavigationStack`. For a sheet:

```swift
.sheet(isPresented: $showingFeedback) {
    HeardockFeedbackView(presentation: .sheet)
}
```

## Theme and localization

Pass a complete custom `HeardockStrings` value when needed, or use the shared partial-override keys in `HeardockConfig`:

```swift
Heardock.shared.configure(HeardockConfig(
    publicKey: "hd_pub_your_key",
    locale: "zh-CN",
    strings: [
        "title": "告诉我们你的想法",
        "send": "提交",
        "networkError": "网络不可用，请稍后重试。"
    ]
))
```

Replace the locale and overrides at runtime; observed SwiftUI views refresh immediately:

```swift
Heardock.shared.updateLocalization(
    locale: "fr-FR",
    strings: ["title": "Envoyer un commentaire"]
)
```

English and Simplified Chinese are built in. Other locales fall back to English unless the caller supplies overrides. Shared keys, placeholders, and error mappings are recorded in `localization.json`.

## Headless submission

```swift
let result = try await Heardock.shared.submit(
    message: "Export freezes at 80%",
    category: .bug
)

if result.queued {
    // Stored locally and retried when the connection returns.
}
```

## Privacy

The publishable key is safe in client code. Device and locale context collection can be disabled with `HeardockCollectOptions`. User identity is attached only through explicit `identify` or submission fields.

## Development

```bash
swift test
```

## License

MIT. See `LICENSE`.
