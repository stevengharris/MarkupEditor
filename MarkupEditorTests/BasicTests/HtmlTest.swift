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
    public var pasteString: String?
    
    public init(description: String? = nil, startHtml: String, endHtml: String? = nil, undoHtml: String? = nil, pasteString: String? = nil) {
        self.description = description
        self.startHtml = startHtml
        self.endHtml = endHtml ?? startHtml
        self.undoHtml = undoHtml
        self.pasteString = pasteString
    }
    
    /// Return an HtmlTest that embeds markers for the selection point(s) in the `startHtml`. The selection to/from are identified using `sel`.
    /// On the JavaScript side, these markers are removed and the corresponding selection is set. The actual HTML that is tested and returned
    /// from the test will not contain the embedded `sel` markers, so endHtml and undoHtml, if set, should not embed such markers.
    /// TODO: For now, the ids, offsets, and index value are set to zero, as they are no longer meaningful.
    public static func withSelection(description: String? = nil, startHtml: String, endHtml: String? = nil, undoHtml: String? = nil, pasteString: String? = nil) -> HtmlTest {
        return HtmlTest(description: description, startHtml: startHtml, endHtml: endHtml, undoHtml: undoHtml, pasteString: pasteString)
    }
    
    public func printDescription() {
        if let description = description { Logger.test.info("\(description)") }
    }
    
}
