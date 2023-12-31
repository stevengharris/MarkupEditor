//
//  MarkupDiv.swift
//  MarkupEditor
//  Adapted from https://stackoverflow.com/a/38885813/8968411
//
//  Created by Steven Harris on 12/26/23.
//

import Foundation
import MarkupEditor

public struct HtmlDiv: Identifiable {
    public var id: String
    public var parentId: String
    public var cssClass: String = "editor"
    public var attributes: EditableAttributes = EditableAttributes.standard
    public var htmlContents: String
    public var buttonGroup: MarkupButtonGroup?
    
    public init(id: String, parentId: String = "editor", cssClass: String, attributes: EditableAttributes, htmlContents: String = "", buttonGroup: MarkupButtonGroup? = nil) {
        self.id = id
        self.parentId = parentId
        self.cssClass = cssClass
        self.attributes = attributes
        self.htmlContents = htmlContents
        self.buttonGroup = buttonGroup
    }
}

public protocol HasMarkupDiv {
    var htmlDiv: HtmlDiv { get set }
}

public protocol MarkupDiv: HasMarkupDiv { }

extension MarkupDiv {
    public var id: String {
        get { htmlDiv.id }
        set { htmlDiv.id = newValue }
    }
    public var parentId: String {
        get { htmlDiv.parentId }
        set { htmlDiv.parentId = newValue }
    }
    public var cssClass: String {
        get { htmlDiv.cssClass }
        set { htmlDiv.cssClass = newValue }
    }
    public var attributes: EditableAttributes {
        get { htmlDiv.attributes }
        set { htmlDiv.attributes = newValue }
    }
    public var htmlContents: String {
        get { htmlDiv.htmlContents }
        set { htmlDiv.htmlContents = newValue }
    }
    public var buttonGroup: MarkupButtonGroup? {
        get { htmlDiv.buttonGroup }
        set { htmlDiv.buttonGroup = newValue }
    }
}
