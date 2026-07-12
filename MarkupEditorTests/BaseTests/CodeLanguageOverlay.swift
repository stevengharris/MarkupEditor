//
//  CodeLanguageOverlay.swift
//  MarkupEditor
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

struct CodeLanguageOverlayCase: Codable, CustomTestStringConvertible {
    let description: String
    let html: String
    let expectedLabel: String?
    var testDescription: String { description }
}

fileprivate struct CodeLanguageOverlayFixture: Codable {
    let description: String
    let tests: [CodeLanguageOverlayCase]
}

fileprivate class CodeLanguageOverlaySuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests: [CodeLanguageOverlayCase] = {
        guard let path = bundle.path(forResource: "code-language-overlay", ofType: "json") else {
            fatalError("code-language-overlay.json could not be located in bundle resources.")
        }
        let data = try! Data(contentsOf: URL(filePath: path))
        return try! JSONDecoder().decode(CodeLanguageOverlayFixture.self, from: data).tests
    }()
}
fileprivate typealias Suite = CodeLanguageOverlaySuite

/// codeLanguageOverlayInfo: label reported for the code_block at the selection.
/// Mirrors markupeditor-base's test/code-language-overlay.json / test/code-language-overlay.test.js
/// (the label matrix only; the pos-invariant check stays JS-only, since it verifies an
/// implementation-position detail rather than a portable label matrix entry).
@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class CodeLanguageOverlay {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: Suite.tests)
    func run(testCase: CodeLanguageOverlayCase) async throws {
        try await page.start()
        guard let webView = page.webView else { return }
        _ = await webView.setTestHtml(testCase.html, sel: "")
        let info = await webView.testCodeLanguageOverlayInfo()
        if let expectedLabel = testCase.expectedLabel {
            #expect(info?.label == expectedLabel)
        } else {
            #expect(info == nil)
        }
    }

}
