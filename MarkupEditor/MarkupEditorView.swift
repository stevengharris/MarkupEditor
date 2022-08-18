//
//  MarkupWebView.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI
import WebKit

/// MarkupEditorView is a SwiftUI view that holds a MarkupWKWebView and (optionally) a MarkupToolbar.
///
/// Specify the MarkupToolbar location separately using MarkupEditor.toolbarLocation. By default, the MarkupWebView has a toolbar
/// at the top for MacCatalyst and iPad, and only uses the inputAccessoryView on the keyboard for iPhone. If you have multiple MarkupWebViews
/// in an application, there should be only one MarkupToolbar. In this case, you should probably specify MarkupEditor.toolbarLocation = .none
/// and then use the MarkupToolbar SwiftUI view directly.
///
/// In general, we don't want WebKit abstractions to leak into the MarkupEditor world. When the MarkupWebView is instantiated, you can optionally
/// specify the WKUIDelegate and WKNavigationDelegate if needed, which will be assigned to the underlying MarkupWKWebView.
public struct MarkupEditorView: View {
    public var markupDelegate: MarkupDelegate?
    private var wkNavigationDelegate: WKNavigationDelegate?
    private var wkUIDelegate: WKUIDelegate?
    private var userScripts: [String]?
    private var resourcesUrl: URL?
    private var id: String?
    private var boundContent: Binding<String>?
    
    public var body: some View {
        VStack(spacing: 0) {
            if MarkupEditor.toolbarLocation == .top {
                MarkupToolbar(markupDelegate: markupDelegate, subToolbarEdge: .bottom)
                Divider()
            }
            MarkupWKWebViewRepresentable(markupDelegate: markupDelegate, wkNavigationDelegate: wkNavigationDelegate, wkUIDelegate: wkUIDelegate, userScripts: userScripts, boundContent: boundContent, resourcesUrl: resourcesUrl, id: id)
            if MarkupEditor.toolbarLocation == .bottom {
                Divider()
                MarkupToolbar(markupDelegate: markupDelegate, subToolbarEdge: .top)
            }
        }
    }
    
    public init(
        markupDelegate: MarkupDelegate? = nil,
        wkNavigationDelegate: WKNavigationDelegate? = nil,
        wkUIDelegate: WKUIDelegate? = nil,
        userScripts: [String]? = nil,
        boundContent: Binding<String>? = nil,
        resourcesUrl: URL? = nil,
        id: String? = nil) {
            self.markupDelegate = markupDelegate
            self.wkNavigationDelegate = wkNavigationDelegate
            self.wkUIDelegate = wkUIDelegate
            self.userScripts = userScripts
            self.boundContent = boundContent
            self.resourcesUrl = resourcesUrl
            self.id = id
        }

}
