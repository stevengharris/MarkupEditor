//
//  InsertImageUrl.swift
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

fileprivate class InsertImageUrlSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "insert-image-url", ofType: "json")).tests
    static let actions: [(MarkupWKWebView) -> Void] = [
        { webview in webview.insertImage(src: tests[0].pasteString!, alt: nil) },
        { webview in webview.insertImage(src: tests[1].pasteString!, alt: nil) },
        { webview in webview.insertImage(src: tests[2].pasteString!, alt: nil) },
    ]
}
fileprivate typealias Suite = InsertImageUrlSuite

@Suite(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class InsertImageUrl {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}
