//
//  HtmlDiv.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 1/17/24.
//

import Foundation

/// A class representing a DIV on the JavaScript side.
///
/// The class is used here so that we can have other structs that implement HtmlDivHolder protocol, which means they have an HtmlDiv instance.
public class HtmlDiv {
    public var id: String
    public var parentId: String
    public var targetId: String?
    public var focusId: String?
    public var cssClass: String = "editor"
    public var attributes: EditableAttributes = EditableAttributes.standard
    public var htmlContents: String
    public var resourcesUrl: URL?
    public var buttonGroup: HtmlButtonGroup?
    public var buttons: [HtmlButton] {
        get { buttonGroup?.buttons ?? [] }
        set {
            if buttonGroup == nil {
                buttonGroup = HtmlButtonGroup(in: id, focusId: focusId, buttons: newValue, dynamic: dynamic)
            } else {
                buttonGroup?.buttons = newValue
            }
        }
    }
    private var dynamic: Bool
    
    public init(id: String, in parentId: String = "editor", targetId: String? = nil, focusId: String? = nil, cssClass: String, attributes: EditableAttributes, htmlContents: String = "", resourcesUrl: URL? = nil, buttons: [HtmlButton]? = nil, dynamic: Bool = false) {
        self.id = id
        self.parentId = parentId
        self.targetId = targetId
        self.focusId = focusId
        self.cssClass = cssClass
        self.attributes = attributes
        self.htmlContents = htmlContents
        self.resourcesUrl = resourcesUrl
        self.dynamic = dynamic
        if let buttons {
            self.buttons = buttons
        }
    }
}


