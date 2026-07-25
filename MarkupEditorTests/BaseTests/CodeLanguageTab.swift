//
//  CodeLanguageTab.swift
//  MarkupEditor
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

struct CodeLanguageTabCase: Codable, CustomTestStringConvertible {
    let description: String
    let html: String
    let expectedLabel: String?
    var testDescription: String { description }
}

fileprivate struct CodeLanguageTabFixture: Codable {
    let description: String
    let tests: [CodeLanguageTabCase]
}

fileprivate class CodeLanguageTabSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests: [CodeLanguageTabCase] = {
        guard let path = bundle.path(forResource: "code-language-tab", ofType: "json") else {
            fatalError("code-language-tab.json could not be located in bundle resources.")
        }
        let data = try! Data(contentsOf: URL(filePath: path))
        return try! JSONDecoder().decode(CodeLanguageTabFixture.self, from: data).tests
    }()
}
fileprivate typealias Suite = CodeLanguageTabSuite

/// codeLanguageTabInfo: label reported for the code_block at the selection.
/// Mirrors markupeditor-base's test/code-language-tab.json / test/code-language-tab.test.js
/// (the label matrix only; the pos-invariant check stays JS-only, since it verifies an
/// implementation-position detail rather than a portable label matrix entry).
@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class CodeLanguageTab {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: Suite.tests)
    func run(testCase: CodeLanguageTabCase) async throws {
        try await page.start()
        guard let webView = page.webView else { return }
        _ = await webView.setTestHtml(testCase.html, sel: "")
        let info = await webView.testCodeLanguageTabInfo()
        if let expectedLabel = testCase.expectedLabel {
            #expect(info?.label == expectedLabel)
        } else {
            #expect(info == nil)
        }
    }

}
