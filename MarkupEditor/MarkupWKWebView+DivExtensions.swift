//
//  MarkupWKWebView+DivExtensions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/15/24.
//

import OSLog

extension MarkupWKWebView {
    
    public func addDiv(_ div: HtmlDivHolder, handler: (()->Void)? = nil) {
        let id = div.id
        let parentId = div.parentId
        let cssClass = div.cssClass
        let attributes = div.attributes
        var jsonAttributes: String?
        if !attributes.isEmpty, let jsonData = try? JSONSerialization.data(withJSONObject: attributes.options) {
            jsonAttributes = String(data: jsonData, encoding: .utf8)
        }
        let htmlContents = div.htmlContents.escaped
        evaluateJavaScript("MU.addDiv('\(id)', '\(parentId)', '\(cssClass)', '\(jsonAttributes ?? "null")', '\(htmlContents)')") { result, error in
            if let error {
                Logger.webview.error("Error adding HtmlDiv: \(error)")
            }
            if let buttonGroup = div.buttonGroup {
                self.addButtonGroup(buttonGroup) {
                    handler?()
                }
            } else {
                handler?()
            }
        }
    }
    
    public func addButtonGroup(_ buttonGroup: HtmlButtonGroup, handler: (()->Void)? = nil) {
        let id = buttonGroup.id
        let parentId = buttonGroup.parentId
        let cssClass = buttonGroup.cssClass
        evaluateJavaScript("MU.addDiv('\(id)', '\(parentId)', '\(cssClass)')") { result, error in
            if let error {
                Logger.webview.error("Error adding HtmlButtonGroup: \(error)")
            } else {
                // We are going to be running handler before all the buttons are added, but we don't care
                for button in buttonGroup.buttons {
                    self.addButton(button, in: id)
                }
            }
            handler?()
        }
    }

    public func addButton(_ button: HtmlButton, in parentId: String, handler: (()->Void)? = nil) {
        let id = button.id
        let cssClass = button.cssClass
        let label = button.label
        evaluateJavaScript("MU.addButton('\(id)', '\(parentId)', '\(cssClass)', '\(label)')") { result, error in
            if let error {
                Logger.webview.error("Error adding HtmlButton: \(error)")
            }
            handler?()
        }
    }
    
    public func focus(on id: String, handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.focusOn('\(id)')") { result, error in
            if let error {
                Logger.webview.error("Error focusing on element with id \(id): \(error)")
            }
            handler?()
        }
    }

}
