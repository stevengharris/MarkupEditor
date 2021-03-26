//
//  String+Extensions.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 3/5/21.
//

import Foundation
import MarkupEditor

extension String {
    
    //MARK:- Html styling and formatting
    
    func untaggedHtml(removing tag: String) -> String? {
        guard let startRange = range(of: Self.startTagFor(tag)) else { return nil }
        var untaggedString = self
        untaggedString.removeSubrange(startRange)
        guard let endRange = untaggedString.range(of: Self.endTagFor(tag)) else { return nil }
        untaggedString.removeSubrange(endRange)
        return untaggedString
    }
    
    func formattedHtml(adding format: FormatContext, startingAt startOffset: Int, endingAt endOffset: Int, withId: String? = nil) -> String {
        var formattedString = self
        let startFormat = Self.startTagFor(format.tag, withId: withId)
        let startIndex = index(self.startIndex, offsetBy: startOffset)
        let endFormat = Self.endTagFor(format.tag)
        formattedString.insert(contentsOf: startFormat, at: startIndex)
        let endIndex = formattedString.index(formattedString.startIndex, offsetBy: endOffset + startFormat.count)
        formattedString.insert(contentsOf: endFormat, at: endIndex)
        return formattedString
    }
    
    func styledHtml(adding style: StyleContext, withId: String? = nil) -> String {
        return Self.startTagFor(style.tag, withId: withId) + self + Self.endTagFor(style.tag)
    }
    
    func unformattedHtml(removing format: FormatContext) -> String? {
        return untaggedHtml(removing: format.tag)
    }
    
    func unstyledHtml(removing style: StyleContext) -> String? {
        return untaggedHtml(removing: style.tag)
    }
    
    static func startTagFor(_ tag: String, withId: String? = nil) -> String {
        let lcTag = tag.lowercased()
        let id = withId != nil ? " id=\"\(withId!)\"" : ""
        return "<\(lcTag)" + id + ">"
    }
    
    static func endTagFor(_ tag: String) -> String {
        let lcTag = tag.lowercased()
        return "</\(lcTag)>"
    }
    
}
