//
//  CodeLanguageMenu.swift
//  MarkupEditor
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

struct CodeLanguageMenuCase: Codable, CustomTestStringConvertible {
    let description: String
    let html: String
    let expected: [String]
    var testDescription: String { description }
}

fileprivate struct CodeLanguageMenuFixture: Codable {
    let description: String
    let tests: [CodeLanguageMenuCase]
}

fileprivate class CodeLanguageMenuSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests: [CodeLanguageMenuCase] = {
        guard let path = bundle.path(forResource: "code-language-menu", ofType: "json") else {
            fatalError("code-language-menu.json could not be located in bundle resources.")
        }
        let data = try! Data(contentsOf: URL(filePath: path))
        return try! JSONDecoder().decode(CodeLanguageMenuFixture.self, from: data).tests
    }()
}
fileprivate typealias Suite = CodeLanguageMenuSuite

/// presentCodeLanguages: distinct language values present among a doc's code_block nodes.
/// Mirrors markupeditor-base's test/code-language-menu.json / test/code-language-menu.test.js
/// (the presentCodeLanguages describe block only; setCodeLanguageCommand stays JS-only, since
/// it's dispatch/transaction side-effect testing rather than a flat input/output matrix).
@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class CodeLanguageMenu {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: Suite.tests)
    func run(testCase: CodeLanguageMenuCase) async throws {
        try await page.start()
        guard let webView = page.webView else { return }
        _ = await webView.setTestHtml(testCase.html, sel: "")
        let languages = await webView.testPresentCodeLanguages()
        #expect(languages == testCase.expected)
    }

}
