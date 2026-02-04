//
//  ListMulti.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/12/25.
//

import MarkupEditor
import Testing

fileprivate class ListMultiSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("list-multi.json").tests
    static let actions: [(MarkupWKWebView) -> Void] = [
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .OL) },
        { webview in webview.toggleListItem(type: .OL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .OL) },
        { webview in webview.toggleListItem(type: .OL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .OL) },
        { webview in webview.toggleListItem(type: .OL) },
        { webview in webview.toggleListItem(type: .OL) },
        { webview in webview.toggleListItem(type: .UL) },
    ]
}
fileprivate typealias Suite = ListMultiSuite

@Suite()
class ListMulti: MarkupDelegate {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)), arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}
