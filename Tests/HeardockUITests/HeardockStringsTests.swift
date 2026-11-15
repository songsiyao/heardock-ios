import XCTest
@testable import HeardockUI

final class HeardockStringsTests: XCTestCase {
    func testOverridesMergeOverEnglishFallback() {
        let strings = HeardockStrings.resolved(
            localeIdentifier: "fr-FR",
            overrides: [
                "title": "Envoyer un commentaire",
                "send": "Envoyer",
                "messagePlaceholder": "Que s’est-il passé ?",
                "networkError": "Hors ligne",
            ]
        )

        XCTAssertEqual(strings.title, "Envoyer un commentaire")
        XCTAssertEqual(strings.send, "Envoyer")
        XCTAssertEqual(strings.messagePlaceholder, "Que s’est-il passé ?")
        XCTAssertEqual(strings.networkMessage, "Hors ligne")
        XCTAssertEqual(strings.closeLabel, "Close")
        XCTAssertEqual(strings.categoryIdea, "Idea")
    }

    func testCanonicalKeysAndTemplatesApplyToChinese() {
        let strings = HeardockStrings.resolved(
            localeIdentifier: "zh-CN",
            overrides: [
                "privacyTemplate": "只有 {app} 可以读取。由 {brand} 提供支持。",
                "referenceLabel": "追踪编号",
                "sendAnother": "再写一条",
                "replyCountTemplate": "{n} 条回复",
            ]
        )

        XCTAssertEqual(strings.privacyPrimary, "只有 团队 可以读取。由 Heardock 提供支持。")
        XCTAssertEqual(strings.sendAnother, "再写一条")
        XCTAssertEqual(strings.replyManyFormat, "%d 条回复")
        XCTAssertEqual(strings.requiredLabel, "必填")
    }
}
