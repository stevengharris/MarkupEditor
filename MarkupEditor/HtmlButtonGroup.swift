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
    public var parentId: String
    public var htmlDiv: HtmlDiv
    public var cssClass: String
    public var buttons: [HtmlButton]
    
    public init(id: String = UUID().uuidString, in parentId: String, focusId: String? = nil, cssClass: String = "markupbuttongroup", buttons: [HtmlButton]) {
        self.id = id
        self.parentId = parentId
        htmlDiv = HtmlDiv(id: id, in: parentId, focusId: focusId, cssClass: "markupbuttongroup", attributes: EditableAttributes.empty)
        self.cssClass = cssClass
        self.buttons = buttons
    }
}
