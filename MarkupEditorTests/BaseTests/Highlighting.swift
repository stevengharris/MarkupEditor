//
//  Highlighting.swift
//  MarkupEditor
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

struct HighlightingCase: Codable, CustomTestStringConvertible {
    let description: String
    let input: String
    let recognized: Bool
    var testDescription: String { description }
}

fileprivate struct HighlightingFixture: Codable {
    let description: String
    let tests: [HighlightingCase]
}

fileprivate class HighlightingSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests: [HighlightingCase] = {
        guard let path = bundle.path(forResource: "highlighting", ofType: "json") else {
            fatalError("highlighting.json could not be located in bundle resources.")
        }
        let data = try! Data(contentsOf: URL(filePath: path))
        return try! JSONDecoder().decode(HighlightingFixture.self, from: data).tests
    }()
}
fileprivate typealias Suite = HighlightingSuite

/// Language recognition matrix for the configured hljs instance (isRecognizedLanguage),
/// covering canonical names, case-insensitivity, aliases, and unrecognized input.
/// Mirrors markupeditor-base's test/highlighting.json / test/highlighting.test.js.
@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class Highlighting {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: Suite.tests)
    func run(testCase: HighlightingCase) async throws {
        try await page.start()
        guard let webView = page.webView else { return }
        let recognized = await webView.testIsRecognizedLanguage(testCase.input)
        #expect(recognized == testCase.recognized)
    }

}
