//
//  InsertInternalLink.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/26/26.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class InsertInternalLinkSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "insert-internal-link", ofType: "json")).tests
    @MainActor static let actions: [@MainActor (MarkupWKWebView) async -> Void] = [
        { webview in await webview.insertInternalLink(hTag: "H1", index: 0) },
        { webview in await webview.insertInternalLink(hTag: "H1", index: 0) },
        { webview in await webview.insertInternalLink(hTag: "H2", index: 1) },
        { webview in await webview.insertInternalLink(hTag: "H2", index: 1) }
    ]
}
fileprivate typealias Suite = InsertInternalLinkSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class InsertInternalLink {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        if let webView = page.webView {
            try await htmlTest.run(action: Suite.actions[index], in: webView)
        }
    }

}
