//
//  HtmlDiv.swift
//  MarkupEditor
//  Adapted from https://stackoverflow.com/a/38885813/8968411
//
//  Created by Steven Harris on 12/26/23.
//

import Foundation

public struct HtmlDiv {
    public var id: String
    public var cssClass: String = "editor"
    public var attributes: EditableAttributes = EditableAttributes.standard
    public var htmlContents: String = ""
    
    public init(id: String, cssClass: String, attributes: EditableAttributes, htmlContents: String) {
        self.id = id
        self.cssClass = cssClass
        self.attributes = attributes
        self.htmlContents = htmlContents
    }
}

public protocol HasHtmlDiv {
    var htmlDiv: HtmlDiv { get set }
}

public protocol DivRepresentable: HasHtmlDiv { }

extension DivRepresentable {
    public var id: String {
        get { htmlDiv.id }
        set { htmlDiv.id = newValue }
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
}
