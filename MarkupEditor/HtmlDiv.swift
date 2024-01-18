//
//  HtmlDiv.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 1/17/24.
//

import Foundation

/// A struct representing a DIV on the JavaScript side.
///
/// The struct is used here so that we can have other structs that implement HtmlDivHolder protocol, which means they have an HtmlDiv instance.
public struct HtmlDiv {
    public var id: String
    public var parentId: String
    public var cssClass: String = "editor"
    public var attributes: EditableAttributes = EditableAttributes.standard
    public var htmlContents: String
    public var buttonGroup: HtmlButtonGroup?
    
    public init(id: String, parentId: String = "editor", cssClass: String, attributes: EditableAttributes, htmlContents: String = "", buttonGroup: HtmlButtonGroup? = nil) {
        self.id = id
        self.parentId = parentId
        self.cssClass = cssClass
        self.attributes = attributes
        self.htmlContents = htmlContents
        self.buttonGroup = buttonGroup
    }
}


