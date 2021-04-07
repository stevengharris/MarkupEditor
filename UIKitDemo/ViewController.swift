//
//  ViewController.swift
//  UIKitDemo
//
//  Created by Steven Harris on 3/9/21.
//

import UIKit
import SwiftUI
import MarkupEditor

class ViewController: UIViewController {
    @IBOutlet weak var toolbarHolder: UIView!
    @IBOutlet weak var toolbarHeightConstraint: NSLayoutConstraint!
    var webView: MarkupWKWebView!
    /// The MarkupCoordinator deals with the interaction with the MarkupWKWebView
    private var coordinator: MarkupCoordinator!
    /// The MarkupToolbar is the SwiftUI component held in the toolbarHolder UIView
    private var toolbar: MarkupToolbar!
    private let toolbarHeight: CGFloat = 53
    private let minWebViewHeight: CGFloat = 30
    private var webViewHeightConstraint: NSLayoutConstraint!
    /// The state of the selection in the MarkupWKWebView, shown in the toolbar
    @Published var selectionState: SelectionState = SelectionState()
    @Published var selectedWebView: MarkupWKWebView?
    /// A binding of selectedWebView used by the MarkupToolbar and its coordinator.
    ///
    /// Since MarkupToolbar uses a SwiftUI-style binding to the selectedWebView, we need to use one
    /// for a UIKit-based app. The toolbar does not (and should not) set the selectedWebView, so this just
    /// lets us use the selectedWebView in UIKit like we use it as @State in the SwiftUI demo ContentView.
    /// We want selectedWebView to be optional in general, since one MarkupToolbar can be used with
    /// multiple MarkupWKWebViews, and it may lose focus as the app is being used. Note that in this demo
    /// app, the markupTookFocus method handled here sets the selectedWebView which in turn updates
    /// the toolbar due to its using the binding.
    var selectedWebViewBinding: Binding<MarkupWKWebView?> { Binding(get: { self.selectedWebView }, set: { self.selectedWebView = $0 }) }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        toolbarHeightConstraint.constant = toolbarHeight
        initializeWebView()
        toolbar = MarkupToolbar(selectionState: selectionState, selectedWebView: selectedWebViewBinding, markupUIDelegate: self)
        add(swiftUIView: toolbar, to: toolbarHolder)
    }
    
    func initializeWebView() {
        // Subclassing WKWebView sure doesn't work well in storyboards.
        // This is because the init(coder: Coder) that is invoked
        // can't provide access to the frame to be able to invoke
        // the proper designated initializer, super.init(frame:configuration:).
        // As a result, there seems to be no way to extract the frame properly
        // from the coder and pass it to the superclass, and we have to
        // set constraints manually here.
        webView = MarkupWKWebView()
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        // To illustrate auto-height adjustment as content changes, define webViewHeightConstraint here and then
        // adjuat it in the heightDidChange callback received by MarkupEventDelegate
        webViewHeightConstraint = webView.heightAnchor.constraint(equalToConstant: minWebViewHeight)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            webView.topAnchor.constraint(equalTo: toolbarHolder.bottomAnchor),
            webViewHeightConstraint
        ])
        webView.html = "<p>Hello <b>bold</b> <i>UIKit</i> world!"
        coordinator = MarkupCoordinator(selectionState: selectionState, markupEventDelegate: self, webView: webView)
        webView.configuration.userContentController.add(coordinator, name: "markup")
    }

}

extension ViewController: MarkupEventDelegate {
    
    func markup(_ view: MarkupWKWebView, heightDidChange height: Int) {
        webViewHeightConstraint.constant = CGFloat(height)
    }
    
    func markupTookFocus(_ view: MarkupWKWebView) {
        selectedWebView = view
    }
    
    func markupSelectionChanged(_ view: MarkupWKWebView) {
        // If the selection is in a link and not across multiple characters, then let the markupUIDelegate decide what to do.
        // The default behavior for the markupUIDelegate is to open the href in selectionState.
        if selectionState.isFollowable {
            markupLinkSelected(view, selectionState: selectionState)
        }
        // If the selection is in an image, then let the markupUIDelegate decide what to do.
        // The default behavior is to do nothing
        if selectionState.isInImage {
            markupImageSelected(view, selectionState: selectionState)
        }
    }
    
}

extension ViewController: MarkupUIDelegate {
    
    func markupImageToolbarAppeared() {
        self.toolbarHeightConstraint.constant = toolbarHeight * 2 + 1       // 1 for the Divider?
    }
    
    func markupImageToolbarDisappeared() {
        self.toolbarHeightConstraint.constant = toolbarHeight
    }
    
}
