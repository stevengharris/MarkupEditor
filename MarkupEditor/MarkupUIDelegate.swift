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
    func markupLinkSelected(_ view: MarkupWKWebView?, selectionState: SelectionState, handler: (()->Void)?)
    
    /// Take action when the user selects an image
    func markupImageSelected(_ view: MarkupWKWebView?, selectionState: SelectionState, handler: ((CGRect?)->Void)?)
    
    func markupImageToolbarAppeared()
    func markupImageToolbarDisappeared()
    func markupLinkToolbarAppeared()
    func markupLinkToolbarDisappeared()

}

extension MarkupUIDelegate {
    
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
    public func markupLinkToolbarAppeared() {}
    public func markupLinkToolbarDisappeared() {}
    
}
