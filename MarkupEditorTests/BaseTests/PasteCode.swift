//
//  PasteCode.swift
//  MarkupEditor
//
//  Created by Steven Harris on 11/4/26.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class PasteCodeSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "paste-code", ofType: "json")).tests
    // Each case sets its own HTML (`skipSet`) and pastes text through MU.pasteCode, which straightens smart quotes.
    static let pastes = ["src=\u{201C}x\u{201D}", "it\u{2019}s \u{2018}quoted\u{2019}", "plain text"]
    @MainActor static var actions: [@MainActor (MarkupWKWebView) async throws -> String?] {
        zip(tests, pastes).map { test, text in
            { webview in
                _ = await webview.setTestHtml(test.startHtml, sel: "|")
                try await webview.executeJavaScript("MU.pasteCode('\(text)')")
                return await webview.getTestHtml(sel: "|")
            }
        }
    }
}
fileprivate typealias Suite = PasteCodeSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class PasteCode {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        if let webView = page.webView {
            try await htmlTest.run(action: Suite.actions[index], in: webView)
        }
    }

}
