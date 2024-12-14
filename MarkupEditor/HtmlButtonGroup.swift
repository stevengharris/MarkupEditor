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
    public var buttons: [HtmlButton]?   // An array or buttons that will be at the trailing edge of the div
    private var dynamic: Bool           // True if the buttons will be added/removed dynamically
    public var isDynamic: Bool { dynamic }
    public var isEmpty: Bool { buttons?.isEmpty ?? false }
    
    public init(in parentId: String, focusId: String? = nil, cssClass: String = "markupbuttongroup", buttons: [HtmlButton]?, dynamic: Bool = false) {
        let bgId = "BG.\(parentId)"
        self.id = bgId
        self.parentId = parentId
        htmlDiv = HtmlDiv(id: bgId, in: parentId, focusId: focusId, cssClass: "markupbuttongroup", attributes: EditableAttributes.empty)
        self.cssClass = cssClass
        self.buttons = buttons
        self.dynamic = dynamic
    }
    
    /// Return a JSON string of this button group that can be used to create it on the JavaScript side, or nil if there is an issue
    public func json(force: Bool = false) -> String? {
        guard let buttons, !isEmpty else { return nil }
        if (!force && isDynamic) { return nil }
        var groupAttributes: [String : Any] = [
            "id": id,
            "parentId": parentId,
            "cssClass": cssClass,
        ]
        var buttonAttributes = [[String : String]]()
        for button in buttons {
            buttonAttributes.append([
                "id": button.id,
                "cssClass": button.cssClass,
                "label": button.label
            ])
        }
        groupAttributes["buttons"] = buttonAttributes
        if let jsonData = try? JSONSerialization.data(withJSONObject: groupAttributes) {
            return String(data: jsonData, encoding: .utf8)
        } else {
            return nil
        }
    }

}
