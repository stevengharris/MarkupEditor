//
//  HtmlTestSuite.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/9/25.
//

import Foundation

/// A class that knows how to decode and return a set of HtmlTest instances from the .json file used in markupeditor-base.
/// The array of HtmlTests is used to drive parameterized tests for the suite.
public class HtmlTestSuite: Codable {
    var description: String
    var tests: [HtmlTest]
    
    init(description: String, tests: [HtmlTest]) {
        self.description = description
        self.tests = tests
    }
    
    static func from(_ filename: String) -> HtmlTestSuite {
        let empty = HtmlTestSuite(description: "Empty suite", tests: [])
        guard
            let url = Bundle(identifier: "com.stevengharris.BaseTests")?.resourceURL?.appendingPathComponent(filename)
        else {
            print("Couldn't find \(filename) in app bundle.")
            return empty
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let suite = try decoder.decode(HtmlTestSuite.self, from: data)
            // We don't use Swift Testing to skip the tests marked using `skipTest`. They
            // will show up as passing, but we modify the description to track them.
            for test in suite.tests {
                if test.skipTest != nil {
                    test.testDescription = "SKIPPED... \(test.description)"
                }
            }
            return suite
        } catch {
            print("Could not decode JSON: \(error)")
            return empty
        }
    }

}
