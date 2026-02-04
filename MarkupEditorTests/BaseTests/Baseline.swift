//
//  Baseline.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/28/26.
//

import Testing
import MarkupEditor

fileprivate class BaselineSuite {
    // Avoid instiantating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("baseline.json").tests
}
fileprivate typealias Suite = BaselineSuite

@Suite()
class Baseline: MarkupDelegate {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        await htmlTest.run(action: nil, in: webView)
    }

}
