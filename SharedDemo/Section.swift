//
//  Section.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 12/27/23.
//

import Foundation
import MarkupEditor

struct Chapter: DivRepresentable, Identifiable {
    var htmlDiv: HtmlDiv
    var id: String
    
    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        htmlDiv = HtmlDiv(id: id, cssClass: "chapter", attributes: EditableAttributes.empty, htmlContents: name)
    }
    
}

struct Section: DivRepresentable, Identifiable {
    var htmlDiv: HtmlDiv
    var id: String
    
    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        htmlDiv = HtmlDiv(id: id, cssClass: "section", attributes: EditableAttributes.empty, htmlContents: name)
    }
    
}

struct SubSection: DivRepresentable, Identifiable {
    var htmlDiv: HtmlDiv
    var id: String
    
    init(id: String = UUID().uuidString, contents: String) {
        self.id = id
        htmlDiv = HtmlDiv(id: id, cssClass: "subsection", attributes: EditableAttributes.standard, htmlContents: contents)
    }
}
