//
//  Style.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/13/25.
//

import MarkupEditor
import Testing

fileprivate class StyleSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("style.json").tests
    static let actions: [(MarkupWKWebView) async -> Void] = [
        { webview in let state = await webview.getSelectionState(); await webview.replaceStyle(state.style, with: .H1) },
        { webview in let state = await webview.getSelectionState(); await webview.replaceStyle(state.style, with: .H6) },
        { webview in let state = await webview.getSelectionState(); await webview.replaceStyle(state.style, with: .P) },
        { webview in let state = await webview.getSelectionState(); await webview.replaceStyle(state.style, with: .PRE) },
        { webview in let state = await webview.getSelectionState(); await webview.replaceStyle(state.style, with: .PRE) }
    ]
}
fileprivate typealias Suite = StyleSuite

@Suite()
class Style: MarkupDelegate {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)), arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}
