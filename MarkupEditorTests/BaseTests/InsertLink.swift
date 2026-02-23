//
//  InsertLink.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/12/25.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class InsertLinkSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "insert-link", ofType: "json")).tests
    @MainActor static var actions: [@MainActor (MarkupWKWebView) -> Void] {
        var actions: [@MainActor (MarkupWKWebView) -> Void] = []
        for test in tests {
            actions.append({ webview in webview.insertLink(test.pasteString!) })
        }
        return actions
    }
}
fileprivate typealias Suite = InsertLinkSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class InsertLink {
    let page: HtmlTestPage = HtmlTestPage()
    
    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        if let webView = page.webView {
            try await htmlTest.run(action: Suite.actions[index], in: webView)
        }
    }

}
