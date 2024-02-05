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
    
    init(id: String = UUID().uuidString, targetId: String? = nil, name: String) {
        htmlDiv = HtmlDiv(id: id, targetId: targetId, cssClass: "title", attributes: EditableAttributes.empty, htmlContents: name)
    }
    
}

struct SectionDiv: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    var buttons: [HtmlButton] {
        get { htmlDiv.buttons }
        set { htmlDiv.buttons = newValue }
    }

    init(id: String = UUID().uuidString, targetId: String? = nil, name: String, buttons: [HtmlButton] = []) {
        htmlDiv = HtmlDiv(id: id, targetId: targetId, cssClass: "section", attributes: EditableAttributes.empty, htmlContents: name, buttons: buttons)
    }
    
}

struct ContentDiv: HtmlDivHolder {
    var htmlDiv: HtmlDiv
    
    init(id: String = UUID().uuidString, targetId: String? = nil, contents: String) {
        htmlDiv = HtmlDiv(id: id, targetId: targetId, cssClass: "content", attributes: EditableAttributes.standard, htmlContents: contents.escaped)
    }
}
