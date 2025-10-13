//
//  HtmlTestSuite.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/9/25.
//

import Foundation

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
