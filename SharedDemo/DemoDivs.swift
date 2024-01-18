//
//  DemoDivs.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 12/27/23.
//

import Foundation
import MarkupEditor

struct Div1: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    
    init(id: String = UUID().uuidString, name: String, buttonGroup: HtmlButtonGroup? = nil) {
        htmlDiv = HtmlDiv(id: id, cssClass: "div1", attributes: EditableAttributes.empty, htmlContents: name, buttonGroup: buttonGroup)
    }
    
}

struct Div2: HtmlDivHolder {
    var htmlDiv: HtmlDiv

    init(id: String = UUID().uuidString, name: String, buttonGroup: HtmlButtonGroup? = nil) {
        htmlDiv = HtmlDiv(id: id, cssClass: "div2", attributes: EditableAttributes.empty, htmlContents: name, buttonGroup: buttonGroup)
    }
    
}

struct Div3: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    
    init(id: String = UUID().uuidString, contents: String, buttonGroup: HtmlButtonGroup? = nil) {
        htmlDiv = HtmlDiv(id: id, cssClass: "div3", attributes: EditableAttributes.standard, htmlContents: contents, buttonGroup: buttonGroup)
    }
}
