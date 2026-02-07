//
//  InsertImageUrl.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/12/25.
//

import MarkupEditor
import Testing

fileprivate class InsertImageUrlSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("insert-image-url.json").tests
    static let actions: [(MarkupWKWebView) -> Void] = [
        { webview in webview.insertImage(src: tests[0].pasteString!, alt: nil) },
        { webview in webview.insertImage(src: tests[1].pasteString!, alt: nil) },
        { webview in webview.insertImage(src: tests[2].pasteString!, alt: nil) },
    ]
}
fileprivate typealias Suite = InsertImageUrlSuite

@Suite()
class InsertImageUrl: MarkupDelegate {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)), arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}
