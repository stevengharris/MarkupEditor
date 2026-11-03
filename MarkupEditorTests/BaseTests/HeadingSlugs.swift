//
//  HeadingSlugs.swift
//  MarkupEditor
//
//  Created by Steven Harris on 11/3/26.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

// The slug functions return strings and arrays, not HTML, so each test case checks the
// result of calling them in the web view directly.
fileprivate class HeadingSlugsSuite {
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "heading-slugs", ofType: "json")).tests
    @MainActor static let actions: [@MainActor (MarkupWKWebView) async throws -> Void] = [
        { webview in
            let slug1 = try await webview.executeJavaScript("MU.headingSlug(\"What's new, a_b-c?\")") as? String
            #expect(slug1 == "whats-new-a_b-c")
        },
        { webview in
            let slug2 = try await webview.executeJavaScript("MU.headingSlug('Über Привет 你好')") as? String
            #expect(slug2 == "über-привет-你好")
        },
        { webview in
            let slug3 = try await webview.executeJavaScript("MU.headingSlug('x\\u00b2 \\u2460 y')") as? String
            #expect(slug3 == "x--y")
            let slug4 = try await webview.executeJavaScript("MU.headingSlug('I \\u2764\\ufe0f it')") as? String
            #expect(slug4 == "i-\u{FE0F}-it")
        },
        { webview in
            let a = String(repeating: "a", count: 39)
            let slug5 = try await webview.executeJavaScript("MU.headingSlug('\(a)\\ud835\\udc9c\\ud835\\udc9c')") as? String
            #expect(slug5 == a + "\u{1D49C}")
            let slug6 = try await webview.executeJavaScript("MU.headingSlug('This paragraph text is long enough to be cut at forty characters')") as? String
            #expect(slug6 == "this-paragraph-text-is-long-enough-to-be")
        },
        { webview in
            let slugs = try await webview.executeJavaScript("MU.headingSlugs(['Setup', 'Other', 'Setup', 'setup', 'Setup!'])") as? [String]
            #expect(slugs == ["setup", "other", "setup-1", "setup-2", "setup-3"])
        },
        { webview in
            _ = await webview.setTestHtml("<h2>Setup</h2><h1>Intro</h1><h2>Setup</h2><p>|x</p>", sel: "|")
            let headers = await webview.getHeaders()
            #expect(headers.map { "\($0.text):\($0.slug)" } == ["Intro:intro", "Setup:setup", "Setup:setup-1"])
        },
    ]
}
fileprivate typealias Suite = HeadingSlugsSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class HeadingSlugs {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        guard let webView = page.webView else { return }
        _ = await webView.setTestHtml(htmlTest.startHtml, sel: htmlTest.sel)
        try await Suite.actions[index](webView)
    }

}
