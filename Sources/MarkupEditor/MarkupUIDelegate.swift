//
//  MarkupUIDelegate.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/17/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation
import UIKit

/// MarkupUIDelegate defines app-specific functionality that may require user-interaction.
///
/// The MarkupToolbar exposes various "insert" operations that depend on the selectionState that then directly invoke the markupInsert function here.
///
/// When a link is selected in the MarkupWebView, the MarkupEventDelegate sees markup(_:selectionChange). The MarkupEventDelegate can then
/// determine if the SelectionState isFollowable, and if so, can invoke the markupLinkSelected method here.
///
/// Default implementations of MarkupUIDelegate methods are provided, so all are optional. The implementations here are meant to be useful as-is, but can be overridden when needed.
public protocol MarkupUIDelegate {
    
    /// Called when invoked from the MarkupToolbar
    /// The implementor should validate that the selectionState is proper for the type of insertion.
    func markupInsert(_ view: MarkupWKWebView?, type: MarkupAlertType, selectionState: SelectionState, handler: @escaping (MarkupError?)->Void)
    /// Return the TextAlert that is appropriate for the MarkupAlertType, which should have alread been validated using markupInsert
    func markupTextAlert(_ view: MarkupWKWebView?, type: MarkupAlertType, selectionState: SelectionState) -> TextAlert
    /// Take action when the user selects a link
    func markupLinkSelected(_ view: MarkupWKWebView?, selectionState: SelectionState, handler: (()->Void)?)

}

extension MarkupUIDelegate {
    
    /// Execute the handler with a MarkupError if view and selectionState are not in the proper condition, else with nil
    public func markupInsert(_ view: MarkupWKWebView?, type: MarkupAlertType, selectionState: SelectionState, handler: @escaping (MarkupError?)->Void) {
        guard let view = view else {
            handler(.prepareInsert)
            return
        }
        switch type {
        case .link:
            // The selection is either on a link or some range of text or both
            if !selectionState.isLinkable {
                handler(.notLinkable)
                return
            }
        default:
            // The selection is between two characters, not on a range
            if !selectionState.isInsertable {
                handler(.notInsertable)
            }
        }
        // Prepare for the insert by setting the selection properly in the view.
        // This ensures the selection is properly restored in the view when the alert goes away.
        view.prepareInsert() { error in
            if error == nil {
                handler(nil)
            } else {
                handler(.prepareInsert)
            }
        }
    }
    
    /// Return a TextAlert, including action, that has been properly populated for display
    public func markupTextAlert(_ view: MarkupWKWebView?, type: MarkupAlertType, selectionState: SelectionState) -> TextAlert {
        switch type {
        case .link:
            let selection = selectionState.link ?? selectionState.selection
            var title: String
            var message: String?
            var placeholder: String?
            var href: String?
            // Disabling of the link button should prevent it, but if for some reason the selection is nil,
            // then by setting the title only and not populating placeholder or text, the alert will
            // show the title only and both buttons will execute with a nil argument in action
            if selection != nil {
                href = selectionState.href
                title = href == nil ? "Add Link" : "Edit Link"
                placeholder = "Enter URL"
                message = "Link to text: \"\(selection!)\""
            } else {
                title = "Error: No text was selected to link to."
            }
            return TextAlert(
                title: title,
                action: { text in
                    if let href = text, !href.isEmpty {
                        view?.insertLink(href)
                    }
                },
                placeholder: placeholder,
                message: message,
                text: href,
                accept: "Link"
            )
        default:
            return TextAlert(
                title: "Implement \(type) alert!",
                action: { text in
                }
            )
        }
    }
    
    /// Open the href specified in selectionState. Override if a different behavior is needed.
    /// This function is used by UIKit and SwiftUI apps, but we just use the UIApplication.shared here for simplicity.
    /// This does, however, force us to import UIKit.
    /// The view and handler are provided to help when overriding the default method.
    public func markupLinkSelected(_ view: MarkupWKWebView?, selectionState: SelectionState, handler: (()->Void)? = nil) {
        // If no handler is provided, the default action is to open the url at href if it can be opened
        guard
            let href = selectionState.href,
            let url = URL(string: href),
            UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
}
