//
//  CallbackButton.swift
//  MarkupEditor
//
//  Created by Steven Harris on 12/28/23.
//

import Foundation

/// A Swift struct that represents a JavaScript button that calls back to the Swift side when pressed.
public struct MarkupButton {
    
    static let labels: [String : String] = [
        "trash" : "􀈑",
        "eye" : "􀋭",
        "link" : "􀉣"
    ]
    
    public var id: String
    public var cssClass: String
    public var label: String
    public var callbackName: String
    
    public init(id: String = UUID().uuidString, cssClass: String = "markupbutton", label: String, callbackName: String) {
        self.id = id
        self.cssClass = cssClass
        if let iconLabel = Self.labels[label] {
            self.label = iconLabel
        } else {
            self.label = label
        }
        self.callbackName = callbackName
    }
}
