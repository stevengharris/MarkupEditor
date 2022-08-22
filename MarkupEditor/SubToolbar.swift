//
//  SubToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 6/27/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The sub-toolbar used for creating/editing links, images, and tables.
public struct SubToolbar: View {
    
    public enum ToolbarType {
        case image
        case link
        case table
        case none
    }

    private var toolbarStyle: ToolbarStyle
    @ObservedObject private var showSubToolbar: ShowSubToolbar
    @ObservedObject private var observedWebView: ObservedWebView = MarkupEditor.observedWebView
    @ObservedObject private var selectionState: SelectionState = MarkupEditor.selectionState
    private var markupDelegate: MarkupDelegate?
    
    public var body: some View {
        //if #available(macCatalyst 15.0, *) {
        //    let _ = Self._printChanges()
        //}
        VStack(spacing: 0) {
            if showSubToolbar.type == .link {
                LinkToolbar()
                    .onAppear {
                        markupDelegate?.markupToolbarAppeared(type: .link)
                    }
                    .onDisappear {
                        markupDelegate?.markupToolbarDisappeared()
                        observedWebView.selectedWebView?.becomeFirstResponder()
                    }
            }
            if showSubToolbar.type == .image {
                ImageToolbar()
                    .onAppear {
                        markupDelegate?.markupToolbarAppeared(type: .image)
                    }
                    .onDisappear {
                        markupDelegate?.markupToolbarDisappeared()
                        observedWebView.selectedWebView?.becomeFirstResponder()
                    }
            }
            if showSubToolbar.type == .table {
                TableToolbar()
                    .onAppear {
                        markupDelegate?.markupToolbarAppeared(type: .table)
                    }
                    .onDisappear {
                        markupDelegate?.markupToolbarDisappeared()
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
