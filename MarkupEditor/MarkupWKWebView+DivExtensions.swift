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
                Logger.webview.error("Error: \(error)")
            }
            handler?()
        }
    }
    
    public func addButtonGroup(_ buttonGroup: HtmlButtonGroup, handler: (()->Void)? = nil) {
        let id = buttonGroup.id
        let cssClass = buttonGroup.cssClass
        let divId = buttonGroup.divId
        evaluateJavaScript("MU.addDiv('\(id)', '\(divId)', '\(cssClass)')") { result, error in
            if let error {
                Logger.webview.error("Error: \(error)")
            }
            handler?()
        }
    }

    public func addButton(_ button: HtmlButton, in divId: String, handler: (()->Void)? = nil) {
        let id = button.id
        let cssClass = button.cssClass
        let label = button.label
        evaluateJavaScript("MU.addButton('\(id)', '\(cssClass)', '\(label)', '\(divId)')") { result, error in
            if let error {
                Logger.webview.error("Error: \(error)")
            }
            handler?()
        }
    }

}
