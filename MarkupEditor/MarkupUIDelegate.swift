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
    /// Take action when the user selectd an image
    func markupImageSelected(_ view: MarkupWKWebView?, selectionState: SelectionState, handler: ((CGRect?)->Void)?)
    func markupImageToolbarAppeared()
    func markupImageToolbarDisappeared()

}

extension MarkupUIDelegate {
    
    /// Execute the handler with a MarkupError if view and selectionState are not in the proper condition, else with nil
    public func markupInsert(_ view: MarkupWKWebView?, type: MarkupAlertType, selectionState: SelectionState, handler: @escaping (MarkupError?)->Void) {
        guard view != nil else {
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
                message = "Link to text: \"\(selection!)\". Clear the URL to remove the link."
            } else {
                title = "Error: No text was selected to link to."
            }
            return TextAlert(
                title: title,
                action: { link, alt in
                    if let href = link, !href.isEmpty {
                        view?.insertLink(href)
                    }
                },
                placeholder1: placeholder,
                message: message,
                text1: href,
                accept: "Link"
            )
        case .image:
            let src = selectionState.src
            let alt = selectionState.alt
            let message = "Enter the URL for the image and a description. Clear the URL to remove the image."
            let placeholder1 = "Enter URL"
            let placeholder2 = "Enter description"
            return TextAlert(
                title: src == nil ? "Add Image" : "Edit Image",
                action: { newSrc, newAlt in
                    if newSrc == nil {
                        view?.modifyImage(src: newSrc, alt: nil, scale: nil)
                    } else if src == nil {
                        view?.insertImage(src: newSrc, alt: newAlt)
                    } else {
                        view?.modifyImage(src: newSrc, alt: newAlt, scale: selectionState.scale)
                    }
                },
                placeholder1: placeholder1,
                placeholder2: placeholder2,
                message: message,
                text1: src,
                text2: alt,
                accept: src == nil ? "Insert" : "Modify"
            )
        default:
            return TextAlert(
                title: "Implement \(type) alert!",
                action: { text, alt in
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
    
    public func markupImageSelected(_ view: MarkupWKWebView?, selectionState: SelectionState, handler: ((CGRect?)->Void)? = nil) {}
    public func markupImageToolbarAppeared() {}
    public func markupImageToolbarDisappeared() {}
    
}
