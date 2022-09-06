//
//  SubToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 6/27/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The sub-toolbar was designed to deal with multiple types of subtoolbars, originally one each for
/// tables, links, and images. However, the user input required for links and images did not work well
/// on non-hardware keyboard, and even then were constrained too much. So, the subtoolbars for
/// links and images were replaced with popovers handled directly by the MarkupWKWebView, the
/// LinkViewController and ImageViewController. The logic for conditionally popularing the SubToolbar
/// is left here in case someone wants to add back in another MarkupToolbar.SubToolbarType.
public struct SubToolbar: View {
    
    private var toolbarStyle: ToolbarStyle
    @ObservedObject private var showSubToolbar: ShowSubToolbar
    @ObservedObject private var observedWebView: ObservedWebView = MarkupEditor.observedWebView
    @ObservedObject private var selectionState: SelectionState = MarkupEditor.selectionState
    private var markupDelegate: MarkupDelegate?
    
    public var body: some View {
        //if #available(iOS 15.0, macCatalyst 15.0, *) {
        //    let _ = Self._printChanges()
        //}
        VStack(spacing: 0) {
            if showSubToolbar.type == .table {
                TableToolbar()
                    .onDisappear {
                        observedWebView.selectedWebView?.becomeFirstResponder()
                    }
            }
            Divider()
        }
        .environmentObject(toolbarStyle)
    }
    
    public init(for markupToolbar: MarkupToolbar) {
        toolbarStyle = markupToolbar.toolbarStyle
        markupDelegate = markupToolbar.markupDelegate
        showSubToolbar = markupToolbar.showSubToolbar
    }
    
}

struct SubToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading) {
            SubToolbar(for: MarkupToolbar(.compact))
            SubToolbar(for: MarkupToolbar(.labeled))
            Spacer()
        }
    }
}
