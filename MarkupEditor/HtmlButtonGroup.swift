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
    public var id: String               // The id of the HTML element corresponding to this div
    public var parentId: String         // The id of the parent div for this div
    public var htmlDiv: HtmlDiv         // The HTMLDiv we are holding onto to be an HTMLDivHolder
    public var cssClass: String         // The CSS class for this div
    public var buttons: [HtmlButton]    // An array or buttons that will be at the trailing edge of the div
    private var dynamic: Bool            // True if the buttons will be added/removed dynamically at focus/blur
    public var isDynamic: Bool { dynamic }
    
    public init(id: String = UUID().uuidString, in parentId: String, focusId: String? = nil, cssClass: String = "markupbuttongroup", buttons: [HtmlButton], dynamic: Bool = false) {
        self.id = id
        self.parentId = parentId
        htmlDiv = HtmlDiv(id: id, in: parentId, focusId: focusId, cssClass: "markupbuttongroup", attributes: EditableAttributes.empty)
        self.cssClass = cssClass
        self.buttons = buttons
        self.dynamic = dynamic
    }

}
