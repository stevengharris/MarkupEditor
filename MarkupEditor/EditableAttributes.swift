//
//  EditableAttributes.swift
//  MarkupEditor
//
//  Created by Steven Harris on 12/26/23.
//

import Foundation

public struct EditableAttributes: OptionSet {
    public let rawValue: Int
    
    public static let contenteditable = EditableAttributes(rawValue: 1 << 0)
    public static let spellcheck = EditableAttributes(rawValue: 1 << 1)
    public static let autocorrect = EditableAttributes(rawValue: 1 << 2)
    
    public static let standard: EditableAttributes = [.contenteditable, .spellcheck, .autocorrect]
    public static let empty: EditableAttributes = []
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /// Return a dictionary of the options that are set in this EditableAttributes instance.
    ///
    /// We use this to get JSON from it, so only the set attributes populate the dictionary with true values.
    var options: [String : Bool] {
        var options: [String : Bool] = [:]
        if contains(.contenteditable) { options["contenteditable"] = true }
        if contains(.spellcheck) { options["spellcheck"] = true }
        if contains(.autocorrect) { options["autocorrect"] = true }
        return options
    }
}
