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
    
    init(id: String = UUID().uuidString, targetId: String? = nil, name: String) {
        htmlDiv = HtmlDiv(id: id, targetId: targetId, cssClass: "div1", attributes: EditableAttributes.empty, htmlContents: name)
    }
    
}

struct Div2: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    var buttons: [HtmlButton] {
        get { htmlDiv.buttons }
        set { htmlDiv.buttons = newValue }
    }

    init(id: String = UUID().uuidString, targetId: String? = nil, name: String, buttons: [HtmlButton] = []) {
        htmlDiv = HtmlDiv(id: id, targetId: targetId, cssClass: "div2", attributes: EditableAttributes.empty, htmlContents: name, buttons: buttons)
    }
    
}

struct Div3: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    
    init(id: String = UUID().uuidString, targetId: String? = nil, contents: String) {
        htmlDiv = HtmlDiv(id: id, targetId: targetId, cssClass: "div3", attributes: EditableAttributes.standard, htmlContents: contents)
    }
}
