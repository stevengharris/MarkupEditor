//
//  ListEnterRange.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/12/25.
//

import MarkupEditor
import Testing

fileprivate class ListEnterRangeSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("list-enter-range.json").tests
    static var actions = Array<(MarkupWKWebView) -> Void>(repeating: { webview in webview.testListEnter() }, count: tests.count)
}
fileprivate typealias Suite = ListEnterRangeSuite

@Suite()
class ListEnterRange: MarkupDelegate {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}
