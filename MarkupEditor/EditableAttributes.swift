//
//  EditableAttributes.swift
//  MarkupEditor
//
//  Created by Steven Harris on 12/26/23.
//

import Foundation

public struct EditableAttributes: @unchecked Sendable, OptionSet {
    public let rawValue: Int
    
    public static let contenteditable = EditableAttributes(rawValue: 1 << 0)
    public static let spellcheck = EditableAttributes(rawValue: 1 << 1)
    public static let autocorrect = EditableAttributes(rawValue: 1 << 2)
    
    public static let standard: EditableAttributes = [.contenteditable, .autocorrect]
    public static let empty: EditableAttributes = []
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /// Return a dictionary of the options that are set in this EditableAttributes instance.
    ///
    /// We use this to get JSON from, so populate the dictionary with booleans for all values.
    ///
    /// NOTE: Currently spellcheck="true" produces a bad behavior wherein a word is selected and then the selection
    /// changes to the end of the paragraph. This may have to do with some underlying mechanics for presenting
    /// suggestions, but for now we will set to "false" by default.
    public var options: [String : Bool] {
        var options: [String : Bool] = [:]
        options["contenteditable"] = contains(.contenteditable)
        options["spellcheck"] = contains(.spellcheck)
        options["autocorrect"] = contains(.autocorrect)
        return options
    }
    
    /// Return a JSON string of `options` or null if there is an issue
    public var json: String? {
        if let jsonData = try? JSONSerialization.data(withJSONObject: options) {
            return String(data: jsonData, encoding: .utf8)
        } else {
            return nil
        }
    }
}
