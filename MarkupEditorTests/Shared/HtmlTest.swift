//
//  HtmlTest.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 4/6/22.
//

import Foundation
import MarkupEditor
import OSLog

public struct HtmlTest {
    public var description: String? = nil
    public var startHtml: String
    public var endHtml: String
    public var undoHtml: String?
    public var startId: String
    public var startOffset: Int
    public var endId: String
    public var endOffset: Int
    public var startChildNodeIndex: Int?
    public var endChildNodeIndex: Int?
    public var pasteString: String?
    
    public init(description: String? = nil, startHtml: String, endHtml: String? = nil, undoHtml: String? = nil, startId: String, startOffset: Int, endId: String, endOffset: Int, startChildNodeIndex: Int? = nil, endChildNodeIndex: Int? = nil, pasteString: String? = nil) {
        self.description = description
        self.startHtml = startHtml
        self.endHtml = endHtml ?? startHtml
        self.undoHtml = undoHtml
        self.startId = startId
        self.startOffset = startOffset
        self.endId = endId
        self.endOffset = endOffset
        self.startChildNodeIndex = startChildNodeIndex
        self.endChildNodeIndex = endChildNodeIndex
        self.pasteString = pasteString
    }
    
    /// Return an HtmlTest that embeds markers for the selection point(s) in the `startHtml`. The selection to/from are identified using `sel`.
    /// On the JavaScript side, these markers are removed and the corresponding selection is set. The actual HTML that is tested and returned
    /// from the test will not contain the embedded `sel` markers, so endHtml and undoHtml, if set, should not embed such markers.
    /// TODO: For now, the ids, offsets, and index value are set to zero, as they are no longer meaningful.
    public static func withSelection(description: String? = nil, startHtml: String, endHtml: String? = nil, undoHtml: String? = nil, pasteString: String? = nil) -> HtmlTest {
        return HtmlTest(description: description, startHtml: startHtml, endHtml: endHtml, startId: "", startOffset: 0, endId: "", endOffset: 0, pasteString: pasteString)
    }
    
    public static func forFormatting(_ rawString: String, style: StyleContext, format: FormatContext, startingAt startOffset: Int, endingAt endOffset: Int, sel: String? = nil) -> HtmlTest {
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
        let styledWithId = rawString.styledHtml(adding: style, startingAt: startOffset, endingAt: endOffset, sel: sel)
        let formattedOnly = rawString.formattedHtml(adding: format, startingAt: startOffset, endingAt: endOffset)
        let styledAndFormatted = formattedOnly.styledHtml(adding: style)
        return HtmlTest(startHtml: styledWithId, endHtml: styledAndFormatted, startId: lcTag, startOffset: startOffset, endId: lcTag, endOffset: endOffset)
    }
    
    public static func forUnformatting(_ rawString: String, style: StyleContext, format: FormatContext, startingAt startOffset: Int, endingAt endOffset: Int, sel: String? = nil) -> HtmlTest {
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
        let formattedWithId = rawString.formattedHtml(adding: format, startingAt: startOffset, endingAt: endOffset)
        let styledAndFormatted = formattedWithId.styledHtml(adding: style, startingAt: startOffset, endingAt: endOffset, sel: sel)
        return HtmlTest(startHtml: styledAndFormatted, endHtml: styledOnly, startId: lcTag, startOffset: 0, endId: lcTag, endOffset: endOffset - startOffset)
    }
    
    public func printDescription() {
        if let description = description { Logger.test.info("\(description)") }
    }
    
}
