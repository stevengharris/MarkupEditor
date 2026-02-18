//
//  Baseline.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/28/26.
//

import Foundation
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class BaselineSuite {
    // Avoid instiantating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "baseline", ofType: "json")).tests
}
fileprivate typealias Suite = BaselineSuite

@Suite()
@MainActor
class Baseline {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)), arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: nil, in: webView)
    }

}
