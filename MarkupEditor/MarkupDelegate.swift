//
//  MarkupDelegate.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/16/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import UIKit

/// MarkupDelegate defines app-specific functionality that will be invoked as the MarkupWKWebView state changes.
///
/// Default implementations of MarkupDelegate methods are provided, so all are optional.
/// Most of the default methods do nothing, although some take care of simple behaviors.
/// Implement any of these methods in your MarkupDelegate to customize the bahavior for your app.
public protocol MarkupDelegate {
    
    /// Called whenever input is received in the view (e.g., typing).
    func markupInput(_ view: MarkupWKWebView)
    
    /// Called when the inner height of the text being displayed changes.
    /// Can be used to update the UI.
    func markup(_ view: MarkupWKWebView, heightDidChange height: Int)
    
    /// Called when the MarkupWKWebView starts editing.
    func markupTookFocus(_ view: MarkupWKWebView)
    
    /// Called when the MarkupWKWebView stops editing or loses focus.
    func markupLostFocus(_ view: MarkupWKWebView)
    
    /// Called when the MarkupWKWebView has become ready to receive input.
    /// More concretely, is called when the internal WKWebView loads for the first time, and contentHtml is set.
    ///
    /// Be sure to execute the handler if you override. The default behavior is to do nothing other than
    /// execute the handler. The MarkupCoordinator uses the handler to have the MarkupWKWebView
    /// becomeFirstResponder.
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?)
    
    /// Called when custom actions are called by callbacks in the JS.
    /// By default, this method is not used unless called by some custom JS that you add.
    func markup(_ view: MarkupWKWebView, handle action: String)
    
    /// Called when the selection changes in the webView.
    func markupSelectionChanged(_ view: MarkupWKWebView)
    
    /// Called when user clicks in the view.
    /// Used to differentiate clicking on a link, image, table from selectionChange.
    func markupClicked(_ view: MarkupWKWebView)
    
    /// Called when an operation on the view pushed something onto the undo stack managed by Undoer
    func markupUndoSet(_ view: MarkupWKWebView)
    
    /// Take action when the user selects a link.
    func markupLinkSelected(_ view: MarkupWKWebView?, selectionState: SelectionState)
    
    /// Take action when the user selects an image.
    func markupImageSelected(_ view: MarkupWKWebView?, selectionState: SelectionState)
    
    /// Take action when the user selects a table.
    func markupTableSelected(_ view: MarkupWKWebView?, selectionState: SelectionState)
    
    /// Take action when a toolbar appeared.
    func markupToolbarAppeared(type: SubToolbar.ToolbarType)
    
    /// Take action when a toolbar disappeared.
    func markupToolbarDisappeared()
    
    /// Take action when the MarkupWKWebView is being set up.
    ///
    /// Called before the web view is setupForEditing.
    func markupSetup(_ view: MarkupWKWebView?)
    
    /// Take action when the MarkupWKWebView is no longer needed.
    func markupTeardown(_ view: MarkupWKWebView?)
    
    /// A locally cached image/resource was added at the url.
    func markupImageAdded(url: URL)
    
    /// A local image has been identified to add to the view.
    func markupImageToAdd(_ view: MarkupWKWebView, url: URL)
    
    /// Respond whether a drop interaction can be handled.
    ///
    /// Returning false, means that neither the markupDropInteraction(\_, sessionDidUpdate) nor
    /// the markupDropInteraction(\_, performDrop) method will be called.
    ///
    /// When using MarkupWebView in SwiftUI, return false to use .onDrop on that view.
    /// This is also the default behavior, so not implementing markupDropInteraction(\_, canHandle)
    /// means you can just use .onDrop with MarkupWebView as you would expect. If you
    /// return true here, the .onDrop will never execute. In this case, you should override
    /// the markupDropInteraction(\_, sessionDidUpdate) and the markupDropInteraction(\_, performDrop)
    /// methods.
    func markupDropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool
    
    /// Respond with a DropProposal
    func markupDropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal
    
    /// Perform the drop
    func markupDropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession)
    
    /// An error occurred on the JavaScript side
    func markupError(code: String, message: String, info: String?, alert: Bool)
    
}

extension MarkupDelegate {
    public func markupInput(_ view: MarkupWKWebView) {}
    public func markup(_ view: MarkupWKWebView, heightDidChange height: Int) {}
    public func markupTookFocus(_ view: MarkupWKWebView) {}
    public func markupLostFocus(_ view: MarkupWKWebView) {}
    public func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) { handler?() }
    public func markup(_ view: MarkupWKWebView, handle action: String) {}
    public func markupSelectionChanged(_ view: MarkupWKWebView) {}
    
    /// The user clicked on something. 
    ///
    /// This default behavior examines the selectionState and invokes more specific methods based on
    /// what is selected. Note that an image can be linked, so the delegate may receive multiple messages.
    public func markupClicked(_ view: MarkupWKWebView) {
        view.getSelectionState() { selectionState in
            // If the selection is a followable link, then let the delegate decide what to do.
            // The default behavior for the delegate is to open the href found in selectionState.
            if selectionState.isFollowable {
                self.markupLinkSelected(view, selectionState: selectionState)
            }
            // If the selection is in an image, let the delegate decide what to do
            if selectionState.isInImage {
                self.markupImageSelected(view, selectionState: selectionState)
            }
            // If the selection is in a table, let the delegate decide what to do
            if selectionState.isInTable {
                self.markupTableSelected(view, selectionState: selectionState)
            }
        }
    }
    
    /// An operation (like bold or listEnter) pushed data onto the Undoer's undo stack.
    ///
    /// The default is to do nothing, but we use this in testing and it might be useful for other integration
    /// on the Swift side.
    public func markupUndoSet(_ view: MarkupWKWebView) {}
    
    /// A link was selected, and selectionState contains information about it.
    ///
    /// This function is used by UIKit and SwiftUI apps, but we just use the UIApplication.shared here for simplicity.
    /// This does, however, force us to import UIKit.
    public func markupLinkSelected(_ view: MarkupWKWebView?, selectionState: SelectionState) {
        // If no handler is provided, the default action is to open the url at href if it can be opened
        guard
            let href = selectionState.href,
            let url = URL(string: href),
            UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    /// An image was selected, and selectionState contains information about it.
    public func markupImageSelected(_ view: MarkupWKWebView?, selectionState: SelectionState) {}
    
    
    /// A table was selected, and selectionState contains information about it.
    public func markupTableSelected(_ view: MarkupWKWebView?, selectionState: SelectionState) {}

    public func markupToolbarAppeared(type: SubToolbar.ToolbarType) {}
    public func markupToolbarDisappeared() {}
    
    /// By default, use the MarkupWKWebView's setup method to populate the cache directory resources.
    ///
    /// Override if you need some custom behavior. For example, you might want to refresh the cache directory
    /// with resources, not fully repopulate it every time, which is what happens in view.setup().
    public func markupSetup(_ view: MarkupWKWebView?) {
        view?.setup()
    }
    
    /// By default, use the MarkupWKWebView's teardown method to remove its entire cache directory.
    ///
    /// Override if you need some custom behavior. For example, you might want to use the cache directory
    /// as a cache by leaving it in place and not cleaning it up every time. If so, you should also implement
    /// markupSetup.
    public func markupTeardown(_ view: MarkupWKWebView?) {
        view?.teardown()
    }
    
    /// Take action after an image had been added, if needed; default is to do nothing.
    ///
    /// You might, for example, want to copy the image to somewhere, since the url passed-in
    /// will be a location in the cache.
    public func markupImageAdded(url: URL) {}
    
    /// Take action needed to add the local image to the document being edited.
    ///
    /// By default, we insert the image at url into view by copying it from the source url here
    /// to a cache. The document references the location relative to the html.
    public func markupImageToAdd(_ view: MarkupWKWebView, url: URL) {
        view.insertLocalImage(url: url)
    }
    
    /// See important comments in the protocol. By default, DropInteraction is not supported; however, in SwiftUI you
    /// can use .onDrop on MarkupWebView without reimplementing this default method.
    public func markupDropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        // An override might be something like: session.canLoadObjects(ofClass: <your model class>.self)
        false
    }
    
    /// Supply a copy proposal by default.
    public func markupDropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        UIDropProposal(operation: .copy)
    }
    
    /// Override this method to perform the drop.
    public func markupDropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {}
    
    /// By default, print to the console when an error occurs on the JavaScript side of the MarkupEditor.
    ///
    /// Most errors are internal and should never occur. See MUError in markup.js for details. The value of alert can be used to filter out
    /// informational errors vs ones you might want to alert users about. If you want to let your user know about an error, then override this
    /// method in your delegate.
    public func markupError(code: String, message: String, info: String?, alert: Bool) {
        print("Error \(code): \(message)")
        if let info = info { print(" \(info)") }
    }
    
}
