//
//  FormatMulti.swift
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

fileprivate class FormatMultiSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "format-multi", ofType: "json")).tests
    @MainActor static let actions: [@MainActor (MarkupWKWebView) -> Void] = [
        { webview in webview.bold() },
        { webview in webview.underline() },
        { webview in webview.italic() },
        { webview in webview.bold() },
        { webview in webview.underline() },
        { webview in webview.italic() },
        { webview in webview.bold() },
        { webview in webview.underline() },
        { webview in webview.italic() },
        { webview in webview.bold() },
        { webview in webview.underline() },
        { webview in webview.italic() },
        { webview in webview.bold() },
        { webview in webview.underline() },
        { webview in webview.italic() },
        { webview in webview.bold() },
        { webview in webview.underline() },
        { webview in webview.italic() },
        { webview in webview.bold() },
        { webview in webview.underline() },
        { webview in webview.italic() },
        { webview in webview.italic() },
    ]
}
fileprivate typealias Suite = FormatMultiSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class FormatMulti {
    let page: HtmlTestPage = HtmlTestPage()
    
    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        if let webView = page.webView {
            try await htmlTest.run(action: Suite.actions[index], in: webView)
        }
    }

}
