//
//  MarkdownShorthand.swift
//  MarkupEditor
//
//  Created by Steven Harris on 11/4/26.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class MarkdownShorthandSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "markdown-shorthand", ofType: "json")).tests
    @MainActor static let actions: [@MainActor (MarkupWKWebView) async throws -> Void] = [
        { webview in try await webview.executeJavaScript("MU.testTypeText('**foo**')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('*foo*')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('_foo_')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('`foo`')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('~~foo~~')") },
        { webview in
            try await webview.executeJavaScript("MU.testTypeText('**foo*')")
            let midway = await webview.getTestHtml(sel: "|")
            #expect(midway?.contains("<em>") == false)
            try await webview.executeJavaScript("MU.testTypeText('*')")
        },
        { webview in
            try await webview.executeJavaScript("MU.testTypeText('**foo**')")
            let converted = await webview.getTestHtml(sel: "|")
            #expect(converted == "<p><strong>foo</strong>|</p>")
            try await webview.executeJavaScript("MU.testTypeKey('Backspace')")
        },
        { webview in try await webview.executeJavaScript("MU.testTypeText('**foo**bar')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('**bold** *em* ~~strike~~')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('```')") },
        { webview in
            try await webview.executeJavaScript("MU.testTypeText('```')")
            try await webview.executeJavaScript("MU.testTypeKey('Enter')")
        },
        { webview in
            try await webview.executeJavaScript("MU.testTypeText('```bash')")
            try await webview.executeJavaScript("MU.testTypeKey('Enter')")
        },
        { webview in
            try await webview.executeJavaScript("MU.testTypeText('```c++')")
            try await webview.executeJavaScript("MU.testTypeKey('Enter')")
        },
        { webview in
            try await webview.executeJavaScript("MU.testTypeText('```bash')")
            try await webview.executeJavaScript("MU.testTypeKey('Enter')")
            try await webview.executeJavaScript("MU.testTypeText('ls -l')")
        },
        { webview in
            try await webview.executeJavaScript("MU.testTypeText('```bash')")
            try await webview.executeJavaScript("MU.testTypeKey('Enter')")
            try await webview.executeJavaScript("MU.doUndo()")
        },
        { webview in
            try await webview.executeJavaScript("MU.testTypeText('```bash')")
            try await webview.executeJavaScript("MU.testTypeKey('Enter')")
        },
        { webview in try await webview.executeJavaScript("MU.testTypeKey('Enter')") },
        { webview in try await webview.executeJavaScript("MU.testTypeKey('Enter')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('**')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('**bold *it* x**')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('snake_case_name')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('a * b * c')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('**foo*')") },
    ]
}
fileprivate typealias Suite = MarkdownShorthandSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class MarkdownShorthand {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        if let webView = page.webView {
            try await htmlTest.run(action: Suite.actions[index], in: webView)
        }
    }

}
