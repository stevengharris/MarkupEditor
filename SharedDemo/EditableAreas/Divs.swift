//
//  Section.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 12/27/23.
//

import Foundation
import MarkupEditor

struct Div1: MarkupDiv {
    var htmlDiv: HtmlDiv
    
    init(id: String = UUID().uuidString, name: String, buttonGroup: MarkupButtonGroup? = nil) {
        htmlDiv = HtmlDiv(id: id, cssClass: "div1", attributes: EditableAttributes.empty, htmlContents: name, buttonGroup: buttonGroup)
    }
    
}

struct Div2: MarkupDiv {
    var htmlDiv: HtmlDiv

    init(id: String = UUID().uuidString, name: String, buttonGroup: MarkupButtonGroup? = nil) {
        htmlDiv = HtmlDiv(id: id, cssClass: "div2", attributes: EditableAttributes.empty, htmlContents: name, buttonGroup: buttonGroup)
    }
    
}

struct Div3: MarkupDiv {
    var htmlDiv: HtmlDiv
    
    init(id: String = UUID().uuidString, contents: String, buttonGroup: MarkupButtonGroup? = nil) {
        htmlDiv = HtmlDiv(id: id, cssClass: "div3", attributes: EditableAttributes.standard, htmlContents: contents, buttonGroup: buttonGroup)
    }
}
