//
//  DemoDivs.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 12/27/23.
//

import Foundation
import MarkupEditor

struct TitleDiv: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    
    init(id: String = UUID().uuidString, contents: String) {
        htmlDiv = HtmlDiv(id: id, cssClass: "title", attributes: EditableAttributes.empty, htmlContents: contents)
    }
    
}

struct SectionDiv: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    var buttons: [HtmlButton]? {
        get { htmlDiv.buttons }
        set { htmlDiv.buttons = newValue }
    }

    init(id: String = UUID().uuidString, focusId: String? = nil, contents: String, buttons: [HtmlButton]? = nil, dynamic: Bool = false) {
        htmlDiv = HtmlDiv(id: id, focusId: focusId, cssClass: "section", attributes: EditableAttributes.empty, htmlContents: contents, buttons: buttons, dynamic: dynamic)
    }
    
}

struct ContentDiv: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    
    init(id: String = UUID().uuidString, contents: String) {
        htmlDiv = HtmlDiv(id: id, cssClass: "content", attributes: EditableAttributes.standard, htmlContents: contents.escaped)
    }
}
