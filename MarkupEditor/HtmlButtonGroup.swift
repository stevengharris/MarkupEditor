//
//  HtmlButtonGroup.swift
//  MarkupEditor
//
//  Created by Steven Harris on 12/29/23.
//

import Foundation

/// A Swift struct that represents a group of HtmlButtons. HtmlButtonGroups are manifested as DIVs that contain HTML buttons.
///
/// We use them so that the CSS styling can push the group of buttons to the edge. They are not typically referenced directly, but are created by
/// adding a button or array of buttons to the MarkupDivStructure, which is always done by identifying the id of the div they reside in.
public class HtmlButtonGroup: HtmlDivHolder {
    public var id: String
    public var htmlDiv: HtmlDiv
    public var cssClass: String
    public var divId: String
    public var buttons: [HtmlButton]
    
    public init(id: String = UUID().uuidString, in divId: String = "editor", cssClass: String = "markupbuttongroup", buttons: [HtmlButton]) {
        self.id = id
        self.divId = divId
        htmlDiv = HtmlDiv(id: id, parentId: divId, cssClass: "markupbuttongroup", attributes: EditableAttributes.empty)
        self.cssClass = cssClass
        self.buttons = buttons
    }
}
