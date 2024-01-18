//
//  MarkupButtonGroup.swift
//  MarkupEditor
//
//  Created by Steven Harris on 12/29/23.
//

import Foundation
import MarkupEditor

/// MarkupButtonGroups are styled containers for buttons.
///
/// We use them so that the CSS styling can push the group of buttons to the edge. They are not typically referenced directly, but are created by
/// adding a button or array of buttons to the MarkupDivStructure, which is always done by identifying the id of the div they reside in.
public class MarkupButtonGroup: MarkupDiv {
    public var id: String
    public var htmlDiv: HtmlDiv
    public var cssClass: String
    public var divId: String
    public var buttons: [MarkupButton]
    
    public init(id: String = UUID().uuidString, in divId: String = "editor", cssClass: String = "markupbuttongroup", buttons: [MarkupButton]) {
        self.id = id
        self.divId = divId
        htmlDiv = HtmlDiv(id: id, parentId: divId, cssClass: "markupbuttongroup", attributes: EditableAttributes.empty)
        self.cssClass = cssClass
        self.buttons = buttons
    }
}
