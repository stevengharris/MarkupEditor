//
//  CallbackButton.swift
//  MarkupEditor
//
//  Created by Steven Harris on 12/28/23.
//

import Foundation
import SwiftUI

/// A Swift struct that represents a JavaScript button that calls back to the Swift side when pressed.
public struct MarkupButton: Identifiable {
    
    static let labels: [String : String] = [
        "trash" : "􀈑",
        "eye" : "􀋭",
        "link" : "􀉣",
    ]
    
    public var id: String
    public var cssClass: String
    public var label: String
    public var action: ()->Void
    
    public init(id: String = UUID().uuidString, cssClass: String = "markupbutton", label: String, action: @escaping ()->Void) {
        self.id = id
        self.cssClass = cssClass
        if let iconLabel = Self.labels[label] {
            self.label = iconLabel
        } else {
            self.label = label
        }
        self.action = action
    }

}
