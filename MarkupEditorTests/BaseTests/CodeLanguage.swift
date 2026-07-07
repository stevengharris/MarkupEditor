//
//  CodeLanguage.swift
//  MarkupEditor
//
//  Created by Steven Harris on 7/5/26.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class CodeLanguageSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "code-language", ofType: "json")).tests
    // Tests with no fixture `action` are pure parse/serialize round-trips (no editing operation),
    // so they use HtmlTest's nil-action path. Tests with `skipSet` combine setTestHtml+getTestHtml
    // into a single String-returning action, matching the fixture's own combined action string.
    static var stringActions: [(@MainActor (MarkupWKWebView) async -> String?)?] {
        var actions: [(@MainActor (MarkupWKWebView) async -> String?)?] = []
        for test in tests {
            if test.skipSet {
                actions.append({ webview in
                    _ = await webview.setTestHtml(test.startHtml, sel: test.sel)
                    return await webview.getTestHtml(sel: test.sel)
                })
            } else {
                actions.append(nil)
            }
        }
        return actions
    }
}
fileprivate typealias Suite = CodeLanguageSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class CodeLanguage {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        guard let webView = page.webView else { return }
        if let stringAction = Suite.stringActions[index] {
            try await htmlTest.run(action: stringAction, in: webView)
        } else {
            try await htmlTest.run(action: nil, in: webView)
        }
    }

}
