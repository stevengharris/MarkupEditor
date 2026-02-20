//
//  Style.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/13/25.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class StyleSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "style", ofType: "json")).tests
    static let actions: [(MarkupWKWebView) async -> Void] = [
        { webview in let state = await webview.getSelectionState(); await webview.replaceStyle(state.style, with: .H1) },
        { webview in let state = await webview.getSelectionState(); await webview.replaceStyle(state.style, with: .H6) },
        { webview in let state = await webview.getSelectionState(); await webview.replaceStyle(state.style, with: .P) },
        { webview in let state = await webview.getSelectionState(); await webview.replaceStyle(state.style, with: .PRE) },
        { webview in let state = await webview.getSelectionState(); await webview.replaceStyle(state.style, with: .PRE) }
    ]
}
fileprivate typealias Suite = StyleSuite

@Suite(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class Style {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}
