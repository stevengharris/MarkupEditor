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
/// If you have multiple MarkupWKWebViews in an application, there should be only one toolbar. In this case, you should probably specify
/// MarkupEditor.toolbarLocation = .none and then use the MarkupToolbarUIView directly.
///
/// In general, we don't want WebKit abstractions to leak into the MarkupEditor world. When the MarkupEditorUIView is instantiated,
/// you can optionally specify the WKUIDelegate and WKNavigationDelegate if needed, which will be assigned to the underlying MarkupWKWebView.
public class MarkupEditorUIView: UIView, MarkupDelegate {
    private var toolbar: MarkupToolbarUIView!
    private var toolbarHeightConstraint: NSLayoutConstraint!
    private var webView: MarkupWKWebView!
    /// The MarkupCoordinator deals with the interaction with the MarkupWKWebView
    private var coordinator: MarkupCoordinator!
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    /// Initialize the MarkupEditorUIView.
    ///
    /// The `isInspectable` attribute for WKWebView was added in iOS 16.4. However, code won't
    /// compile in MacOS versions prior to Ventura (MacOS 10.13). Just checking at runtime for iOS 16.4 doesn't
    /// work for macCatalyst builds on Monterey (MacOS 12.6), because `#available(iOS 16.4, *)`
    /// returns `true`. The only way to make builds work for both macCatalyst and iOS on Ventura+ and
    /// Monterey that I could find was to check on `compiler(>=5.8)` to avoid compiling
    /// `webView.isInspectable = true` on Monterey. Then on Ventura+, we still need a check
    /// on `#available(iOS 16.4, *)`. Now we can build on Ventura+ for iOS 15.5 and 16.4, and for
    /// macCatalyst 16.4, and we can build on Monterey for iOS 15.5 for pre-iOS 16.4 versions. This gating
    /// also allows GitHub actions that use the older MacOS version to work, even if you're working locally on
    /// Ventura.
    public init(
        markupDelegate: MarkupDelegate? = nil,
        wkNavigationDelegate: WKNavigationDelegate? = nil,
        wkUIDelegate: WKUIDelegate? = nil,
        userScripts: [String]? = nil,
        html: String?,
        placeholder: String? = nil,
        selectAfterLoad: Bool = true,
        resourcesUrl: URL? = nil,
        id: String? = nil) {
            super.init(frame: CGRect.zero)
            webView = MarkupWKWebView(html: html, placeholder: placeholder, selectAfterLoad: selectAfterLoad, resourcesUrl: resourcesUrl, id: "Document", markupDelegate: markupDelegate ?? self)
            // The coordinator acts as the WKScriptMessageHandler and will receive callbacks
            // from markup.js using window.webkit.messageHandlers.markup.postMessage(<message>)
            coordinator = MarkupCoordinator(markupDelegate: markupDelegate, webView: webView)
            webView.configuration.userContentController.add(coordinator, name: "markup")
            coordinator.webView = webView
#if compiler(>=5.8)
            if #available(iOS 16.4, *) {
                webView.isInspectable = MarkupEditor.isInspectable
            }
#endif
            // By default, the webView responds to no navigation events unless the navigationDelegate is set
            // during initialization of MarkupEditorUIView.
            webView.navigationDelegate = wkNavigationDelegate
            webView.uiDelegate = wkUIDelegate
            webView.userScripts = userScripts
            webView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(webView)
            if MarkupEditor.toolbarLocation == .top {
                toolbar = MarkupToolbarUIView(markupDelegate: markupDelegate).makeManaged()
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
                toolbar = MarkupToolbarUIView(markupDelegate: markupDelegate).makeManaged()
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
                // for the scenario that requires an override of inputAccessoryView
                webView.inputAccessoryView = MarkupToolbarUIView.inputAccessory(markupDelegate: markupDelegate)
            }
        }
    
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
