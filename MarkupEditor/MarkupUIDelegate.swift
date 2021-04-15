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
/// When a link is selected in the MarkupWebView, the MarkupEventDelegate sees markupClicked. The MarkupEventDelegate can then
/// determine if the SelectionState isFollowable, and if so, can invoke the markupLinkSelected method here. Coordination between the
/// MarkupEventDelegate and the MarkupUIDelegate has to be done in the app. For reference, the demos show how to do it.
///
/// Default implementations of MarkupUIDelegate methods are provided, so all are optional. The implementations here are meant to be useful as-is, but can be overridden when needed.
public protocol MarkupUIDelegate {
    
    /// Take action when the user selects a link
    func markupLinkSelected(_ view: MarkupWKWebView?, selectionState: SelectionState)
    
    /// Take action when the user selects an image
    func markupImageSelected(_ view: MarkupWKWebView?, selectionState: SelectionState)
    
    /// Take action when the user selects a table
    func markupTableSelected(_ view: MarkupWKWebView?, selectionState: SelectionState)
    
    /// Take action when a toolbar appeared
    func markupToolbarAppeared(type: MarkupToolbar.ToolbarType)
    
    /// Take action when a toolbar disappeared
    func markupToolbarDisappeared(type: MarkupToolbar.ToolbarType)

}

extension MarkupUIDelegate {
    
    /// We know a link was selected, and selectionState contains information about it.
    /// The default behavior is to open the href specified in selectionState. Override if a different behavior is needed.
    ///
    /// The default behavior in the MarkupEventDelegate is to invoke this method when a link is clicked-on.
    /// This function is used by UIKit and SwiftUI apps, but we just use the UIApplication.shared here for simplicity.
    /// This does, however, force us to import UIKit.
    /// The view is provided to help when overriding the default method.
    public func markupLinkSelected(_ view: MarkupWKWebView?, selectionState: SelectionState) {
        // If no handler is provided, the default action is to open the url at href if it can be opened
        guard
            let href = selectionState.href,
            let url = URL(string: href),
            UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    /// We know an image was selected, and selectionState contains information about it.
    /// Default behavior is to do nothing. Override if a different behavior is needed.
    ///
    /// The default behavior in the MarkupEventDelegate is to invoke this method when an image is clicked-on.
    /// The view is provided to help when overriding the default method.
    public func markupImageSelected(_ view: MarkupWKWebView?, selectionState: SelectionState) {}
    
    
    /// We know a table was selected, and selectionState contains information about it.
    /// Default behavior is to do nothing. Override if a different behavior is needed.
    ///
    /// The default behavior in the MarkupEventDelegate is to invoke this method when a table is clicked-on.
    /// The view is provided to help when overriding the default method.
    public func markupTableSelected(_ view: MarkupWKWebView?, selectionState: SelectionState) {}

    public func markupToolbarAppeared(type: MarkupToolbar.ToolbarType) {}
    public func markupToolbarDisappeared(type: MarkupToolbar.ToolbarType) {}
    
}
