//
//  MarkupStateHolder.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/6/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation

/// The MarkupStateHolder must be a class that conforms to ObservableObject.
///
/// Since the MarkupToolbar can be used to interact with multiple MarkupWebViews or MarkupWKWebViews,
/// someone has to hold onto the selectedWebView and selectionState so that the MarkupToolbar knows
/// how to keep its display properly updated and how to invoke operations against the selectedWebView.
/// The MarkupStateHolder needs to specify @Published on its selectedWebView and selectionState.
/// 
/// For UIKit, MarkupStateHolder can be a UIViewController or whatever makes sense.
/// For SwiftUI, MarkupStateHolder can be held as a class property of ContentView or your @main App.
/// For unit tests, the test instance can be MarkupStateHolder and MarkupEventDelegate
public protocol MarkupStateHolder: ObservableObject {
    
    /// The selected MarkupWKWebView, assigned when focus event is received
    var selectedWebView: MarkupWKWebView? { get set }
    /// The SelectionState, updated when the selectionChange event is received
    var selectionState: SelectionState  { get set }
    
}

