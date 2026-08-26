//
//  GetHeaders.swift
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

// getHeaders() returns structured data, not HTML, so this doesn't fit either of
// HtmlTest.run's two overloads (both compare a resulting HTML/JSON *string* against
// endHtml). Instead, decode endHtml as [HeaderInfo] too and compare structurally.
fileprivate class GetHeadersSuite {
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "get-headers", ofType: "json")).tests
}
fileprivate typealias Suite = GetHeadersSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class GetHeaders {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: Suite.tests)
    func run(htmlTest: HtmlTest) async throws {
        try await page.start()
        guard let webView = page.webView else { return }
        _ = await webView.setTestHtml(htmlTest.startHtml, sel: htmlTest.sel)
        let actual = await webView.getHeaders()
        let expected = try JSONDecoder().decode([HeaderInfo].self, from: Data(htmlTest.endHtml.utf8))
        #expect(actual == expected)
    }

}
