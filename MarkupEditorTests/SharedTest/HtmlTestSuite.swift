//
//  HtmlTestSuite.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/9/25.
//

import Foundation
import MarkupEditor

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
        let empty = HtmlTestSuite(description: "Empty suite", tests: [])
        guard let path else { return empty }
        let url = URL(filePath: path)
        guard FileManager.default.fileExists(atPath: url.path()) else {
            print("Could not find data file \(path).")
            return empty
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let suite = try decoder.decode(HtmlTestSuite.self, from: data)
            return suite
        } catch {
            print("Could not decode JSON: \(error)")
            return empty
        }
    }
    
    public static func from(_ filename: String, for anyClass: AnyClass? = nil) -> HtmlTestSuite {
        let empty = HtmlTestSuite(description: "Empty suite", tests: [])
        let bundle = anyClass == nil ? Bundle(identifier: "com.stevengharris.BaseTests") : Bundle(for: anyClass!)
        if bundle == nil {
            print("Could not find bundle for suite.")
            return empty
        }
        let resourceURL = bundle!.resourceURL
        if (resourceURL == nil) {
            print("Could not find resourceURL for bundle.")
            return empty
        }
        let url = resourceURL!.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: url.path()) {
            print("Bundle url: \(bundle!.bundleURL)")
            print("Could not find data file \(url.path()).")
            return empty
        } else {
            print("Data file at: \(url.path()).")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let suite = try decoder.decode(HtmlTestSuite.self, from: data)
            return suite
        } catch {
            print("Could not decode JSON: \(error)")
            return empty
        }
    }

}
