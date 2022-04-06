//
//  HtmlTest.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 4/6/22.
//

import Foundation
import MarkupEditor

struct HtmlTest {
    var description: String? = nil
    var startHtml: String
    var endHtml: String
    var startId: String
    var startOffset: Int
    var endId: String
    var endOffset: Int
    var startChildNodeIndex: Int?
    var endChildNodeIndex: Int?
    var pasteString: String?
    
    static func forFormatting(_ rawString: String, style: StyleContext, format: FormatContext, startingAt startOffset: Int, endingAt endOffset: Int) -> HtmlTest {
        // Return an HTMLTest appropriate for formatting a range from startOffset to endOffset in styled HTML
        // For example, to test bolding of the word "is" in the following: <p id: "p">This is a start.</p>, use:
        //      HtmlTest.forFormatting("This is a start.", style: .P, format: .B, startingAt: 5, endingAt: 7)
        // This populates the HtmlTest as follows:
        //  - startHtml : "<p id=\"p\">This is a start.</p>"
        //  - endHtml : "<p id=\"p\">This <b>is</b> a start.</p>"
        //  - startId : "p"
        //  - startOffset : 5
        //  - endId : "p"
        //  - endOffset : 7
        let lcTag = style.tag.lowercased()
        let styledWithId = rawString.styledHtml(adding: style, withId: lcTag)
        let formattedOnly = rawString.formattedHtml(adding: format, startingAt: startOffset, endingAt: endOffset)
        let styledAndFormatted = formattedOnly.styledHtml(adding: style, withId: lcTag)
        return HtmlTest(startHtml: styledWithId, endHtml: styledAndFormatted, startId: lcTag, startOffset: startOffset, endId: lcTag, endOffset: endOffset)
    }
    
    static func forUnformatting(_ rawString: String, style: StyleContext, format: FormatContext, startingAt startOffset: Int, endingAt endOffset: Int) -> HtmlTest {
        // Return an HTMLTest appropriate for unformatting a range from startOffset to endOffset in styled HTML
        // For example, to test unbolding of the word "is" in the following: <p>This <b id: "b">is</b> a start.</p>, use:
        //      HtmlTest.forUnformatting("This is a start.", style: .P, format: .B, startingAt: 5, endingAt: 7)
        // This populates the HtmlTest as follows:
        // - startHtml : "<p>This <b id=\"b\">is</b> a start.</p>"
        // - endHtml : "<p>This is a start.</p>"
        // - startId : "b"
        // - startOffset : 0
        // - endId : "b"
        // - endOffset : 2
        let lcTag = format.tag.lowercased()
        let styledOnly = rawString.styledHtml(adding: style)
        let formattedWithId = rawString.formattedHtml(adding: format, startingAt: startOffset, endingAt: endOffset, withId: lcTag)
        let styledAndFormatted = formattedWithId.styledHtml(adding: style)
        return HtmlTest(startHtml: styledAndFormatted, endHtml: styledOnly, startId: lcTag, startOffset: 0, endId: lcTag, endOffset: endOffset - startOffset)
    }
    
    func printDescription() {
        if let description = description { print(" * Test: \(description)") }
    }
    
}
