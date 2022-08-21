//
//  MarkupEditorUIView.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/18/22.
//

import WebKit
import Combine

/// MarkupEditorUIView is a UIKit view that holds a MarkupWKWebView and (optionally) a MarkupToolbarUIView.
///
/// Specify the toolbar location separately using MarkupEditor.toolbarLocation. By default, the MarkupEditorUIView has a toolbar
/// at the top for all devices.
///
/// This MarkupEditorUIView observes changes to the MarkupEditor.showSubToolbar.type to adjust the toolbarHeightConstraint to
/// accommodate the SubToolbar as needed. The MarkupWKWebView responds to keyboard show/hide events and by default includes
/// the CorrectionToolbar only, along with the hideKeyboard button on the right.
///
/// If you have multiple MarkupWKWebViews in an application, there should be only one toolbar. In this case, you should probably specify
/// MarkupEditor.toolbarLocation = .none and then use the MarkupToolbarUIView directly. If you do that, then you will need your UIView that
/// holds the MarkupToolbarUIView to observe changes to the MarkupEditor.showSubToolbar.type to adjust the toolbar height like this
/// view does. The SwiftUI MarkupToolbar handles such things itself, but that doesn't seem to fly in the UIKit world when consuming
/// SwiftUI views 🤷‍♂️.
///
/// In general, we don't want WebKit abstractions to leak into the MarkupEditor world. When the MarkupEditorUIView is instantiated,
/// you can optionally specify the WKUIDelegate and WKNavigationDelegate if needed, which will be assigned to the underlying MarkupWKWebView.
public class MarkupEditorUIView: UIView, MarkupDelegate {
    private var toolbar: MarkupToolbarUIView!
    private var toolbarHeightConstraint: NSLayoutConstraint!
    private var showSubToolbarType: AnyCancellable?
    private var webView: MarkupWKWebView!
    /// The MarkupCoordinator deals with the interaction with the MarkupWKWebView
    private var coordinator: MarkupCoordinator!
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    public init(
        markupDelegate: MarkupDelegate? = nil,
        wkNavigationDelegate: WKNavigationDelegate? = nil,
        wkUIDelegate: WKUIDelegate? = nil,
        userScripts: [String]? = nil,
        html: String?,
        resourcesUrl: URL? = nil,
        id: String? = nil) {
            super.init(frame: CGRect.zero)
            observeShowSubToolbarType()
            webView = MarkupWKWebView(html: html, resourcesUrl: resourcesUrl, id: "Document", markupDelegate: markupDelegate ?? self)
            // The coordinator acts as the WKScriptMessageHandler and will receive callbacks
            // from markup.js using window.webkit.messageHandlers.markup.postMessage(<message>)
            coordinator = MarkupCoordinator(markupDelegate: markupDelegate, webView: webView)
            webView.configuration.userContentController.add(coordinator, name: "markup")
            coordinator.webView = webView
            // By default, the webView responds to no navigation events unless the navigationDelegate is set
            // during initialization of MarkupEditorUIView.
            webView.navigationDelegate = wkNavigationDelegate
            webView.uiDelegate = wkUIDelegate
            webView.userScripts = userScripts
            webView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(webView)
            if MarkupEditor.toolbarLocation == .top {
                toolbar = MarkupToolbarUIView(markupDelegate: markupDelegate, subToolbarEdge: .bottom)
                toolbar.translatesAutoresizingMaskIntoConstraints = false
                toolbarHeightConstraint = NSLayoutConstraint(item: toolbar!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: MarkupEditor.toolbarStyle.height())
                addSubview(toolbar) // Is on top
                NSLayoutConstraint.activate([
                    toolbar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                    toolbarHeightConstraint,
                    toolbar.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
                    toolbar.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor),
                    webView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: MarkupEditor.toolbarStyle.height()),
                    webView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
                    webView.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
                    webView.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor)
                ])
            } else if MarkupEditor.toolbarLocation == .bottom {
                toolbar = MarkupToolbarUIView(markupDelegate: markupDelegate, subToolbarEdge: .top)
                toolbar.translatesAutoresizingMaskIntoConstraints = false
                toolbarHeightConstraint = NSLayoutConstraint(item: toolbar!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: MarkupEditor.toolbarStyle.height())
                addSubview(toolbar) // Is on top
                NSLayoutConstraint.activate([
                    webView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                    webView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -MarkupEditor.toolbarStyle.height()),
                    webView.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
                    webView.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor),
                    toolbar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
                    toolbarHeightConstraint,
                    toolbar.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
                    toolbar.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor)
                ])
            } else {
                NSLayoutConstraint.activate([
                    webView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                    webView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
                    webView.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
                    webView.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor)
                ])
            }
        }
    
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func observeShowSubToolbarType() {
        showSubToolbarType = MarkupEditor.showSubToolbar.$type.sink { [weak self] type in
            if type == .none {
                self?.toolbarHeightConstraint?.constant = MarkupEditor.toolbarStyle.height()
            } else {
                self?.toolbarHeightConstraint?.constant = 2.0 * MarkupEditor.toolbarStyle.height()
            }
        }
    }

}
