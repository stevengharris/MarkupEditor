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
    public var tests: [HtmlTest]
    
    init(description: String, tests: [HtmlTest]) {
        self.description = description
        self.tests = tests
    }
    
    public static func from(path: String?) -> HtmlTestSuite {
        guard let path else {
            return dataFileProblem(error: "Data file could not be located in bundle resources.")
        }
        let url = URL(filePath: path)
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let suite = try decoder.decode(HtmlTestSuite.self, from: data)
            return suite
        } catch {
            return dataFileProblem(error: "Could not decode JSON: \(error)")
        }
    }
    
    /// Return an HtmlSuite with one test that fails.
    /// Rather than test an empty suite (which is not an error), test one that has a failing test.
    static func dataFileProblem(error: String) -> HtmlTestSuite {
        let test = HtmlTest(
            description: "Data file problem.",
            startHtml: "<p>\(error)</p>",
            endHtml: "<p></p>"
        )
        return HtmlTestSuite(description: "Data file problem.", tests: [test])
    }

}
