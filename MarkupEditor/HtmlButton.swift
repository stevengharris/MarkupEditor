//
//  HtmlButton.swift
//  MarkupEditor
//
//  Created by Steven Harris on 12/28/23.
//

import Foundation

/// A Swift struct that represents an HTML button that calls back to the Swift side when pressed.
///
/// An HtmlButton always resides in an HtmlDiv of some kind, typically an HtmlButtonGroup.
public struct HtmlButton {
    
    public struct ActionInfo {
        public let view: MarkupWKWebView
        public let originId: String
        public let targetId: String?
        public let rect: CGRect
    }
    
    public var id: String
    public var cssClass: String
    public var label: String
    public var targetId: String?
    public var action: (ActionInfo)->Void
    
    public init(id: String = UUID().uuidString, cssClass: String = "markupbutton", label: String, targetId: String? = nil, action: @escaping (ActionInfo)->Void) {
        self.id = id
        self.cssClass = cssClass
        self.label = label
        self.targetId = targetId
        self.action = action
    }
    
    public func executeAction(view: MarkupWKWebView, rect: CGRect) {
        let actionInfo = ActionInfo(view: view, originId: id, targetId: targetId, rect: rect)
        action(actionInfo)
    }

}
