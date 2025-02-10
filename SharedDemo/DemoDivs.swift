//
//  DemoDivs.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 12/27/23.
//

import Foundation
import MarkupEditor

/// A TitleDiv contains only uneditable text with a cssClass indicating it is a title.
///
/// The css is specified in demoDivs.css.
struct TitleDiv: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    
    init(id: String = UUID().uuidString, contents: String) {
        htmlDiv = HtmlDiv(id: id, cssClass: "title", attributes: EditableAttributes.empty, htmlContents: "<p>\(contents)</p>")
    }
    
}

/// A SectionDiv contains uneditable text on the left and possibly buttons on the right. The buttons can be a static part of the div or added dynamically later.
///
/// The css is specified in demoDivs.css.
struct SectionDiv: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    var buttons: [HtmlButton]? {
        get { htmlDiv.buttons }
        set { htmlDiv.buttons = newValue }
    }

    init(id: String = UUID().uuidString, focusId: String? = nil, contents: String, buttons: [HtmlButton]? = nil, dynamic: Bool = false) {
        htmlDiv = HtmlDiv(id: id, focusId: focusId, cssClass: "section", attributes: EditableAttributes.empty, htmlContents: "<p>\(contents)</p>", buttons: buttons, dynamic: dynamic)
    }
    
}

/// A ContentDiv contains html that can be edited.
///
/// The css is specified in demoDivs.css.
struct ContentDiv: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    
    init(id: String = UUID().uuidString, htmlContents: String) {
        htmlDiv = HtmlDiv(id: id, cssClass: "content", attributes: EditableAttributes.standard, htmlContents: htmlContents)
    }
}
