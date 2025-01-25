//
//  String+Extensions.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 3/5/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation
import MarkupEditor

public extension String {
    
    //MARK: Html styling and formatting
    
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
    
    func styledHtml(adding style: StyleContext, startingAt start: Int? = nil, endingAt end: Int? = nil, sel: String? = nil) -> String {
        guard let start, let end, let sel else {
            return Self.startTagFor(style.tag) + self + Self.endTagFor(style.tag)
        }
        var withSel = self
        let iStart = withSel.index(startIndex, offsetBy: start)
        let iEnd = withSel.index(startIndex, offsetBy: end + sel.count)
        withSel.insert(contentsOf: sel, at: iStart)
        withSel.insert(contentsOf: sel, at: iEnd)
        return Self.startTagFor(style.tag) + withSel + Self.endTagFor(style.tag)
    }
    
    func unformattedHtml(removing format: FormatContext) -> String? {
        return untaggedHtml(removing: format.tag)
    }
    
    func unstyledHtml(removing style: StyleContext) -> String? {
        return untaggedHtml(removing: style.tag)
    }
    
    func imageFileNameInTag() -> String? {
        // The string must be a valid <img> tag, like <img src="2537ACEF-A318-4395-8955-8F2C73701AD0.png">
        guard
            contains("<img"),
            let srcRange = range(of: "src=\"") else {
            return nil
        }
        let imageFileNameSize = UUID().uuidString.count + 4    // The image file name will always be a UUID + extension
        let startIndex = srcRange.upperBound
        let endIndex = index(startIndex, offsetBy: imageFileNameSize)
        return String(self[startIndex..<endIndex])
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
