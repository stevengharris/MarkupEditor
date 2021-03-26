//
//  ViewController.swift
//  UIKitDemo
//
//  Created by Steven Harris on 3/9/21.
//

import UIKit
import MarkupEditor

class ViewController: UIViewController, MarkupStateHolder {
    @IBOutlet weak var toolbarHolder: UIView!
    @IBOutlet weak var webView: MarkupWKWebView!
    @IBOutlet weak var toolbarHeightConstraint: NSLayoutConstraint!
    /// The MarkupCoordinator deals with the interaction with the MarkupWKWebView
    private var coordinator: MarkupCoordinator<ViewController>!
    /// The MarkupToolbar is the SwiftUI component held in the toolbarHolder UIView
    private var toolbar: MarkupToolbar<ViewController>!
    private let minWebViewHeight: CGFloat = 30
    private var webViewHeightConstraint: NSLayoutConstraint!
    
    /// The MarkupWKWebView that has focus and will be acted up on by the toolbar
    @Published var selectedWebView: MarkupWKWebView?
    /// The state of the selection in the MarkupWKWebView, shown in the toolbar
    @Published var selectionState: SelectionState = SelectionState()
    /// The object that will be notified of changes as the MarkupWKWebView is edited, this ViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        toolbar = MarkupToolbar(markupStateHolder: self, markupUIDelegate: self)
        add(swiftUIView: toolbar, to: toolbarHolder)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Subclassing WKWebView sure doesn't work well in storyboards.
        // This is because the init(coder: Coder) that is invoked
        // can't provide access to the frame to be able to invoke
        // the proper designated initializer, super.init(frame:configuration:).
        // As a result, there seems to be no way to extract the frame properly
        // from the coder and pass it to the superclass, and we have to
        // set constraints manually here.
        webView.translatesAutoresizingMaskIntoConstraints = false
        webViewHeightConstraint = webView.heightAnchor.constraint(equalToConstant: minWebViewHeight)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            webView.topAnchor.constraint(equalTo: toolbarHolder.bottomAnchor),
            webViewHeightConstraint
        ])
        webView.html = "<p>Hello <b>bold</b> <i>UIKit</i> world!"
        coordinator = MarkupCoordinator(markupStateHolder: self, markupEventDelegate: self, webView: webView)
        webView.configuration.userContentController.add(coordinator, name: "markup")
    }
    
    func markup(_ view: MarkupWKWebView, heightDidChange height: Int) {
        webViewHeightConstraint.constant = CGFloat(height)
    }

}

extension ViewController: MarkupEventDelegate {
    
    func markupSelectionChanged(_ view: MarkupWKWebView, selectionState: SelectionState) {
        // If the selection is in a link and not across multiple characters, then let the markupUIDelegate decide what to do.
        // The default behavior for the markupUIDelegate is to open the href in selectionState.
        if selectionState.isFollowable {
            markupLinkSelected(view, selectionState: selectionState)
        }
        // If the selection is in a link and not across multiple characters, then let the markupUIDelegate decide what to do.
        // The default behavior is to do nothing
        if selectionState.isInImage {
            markupImageSelected(view, selectionState: selectionState)
        }
    }
    
}

extension ViewController: MarkupUIDelegate {
    
}
