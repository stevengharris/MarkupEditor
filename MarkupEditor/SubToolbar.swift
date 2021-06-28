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
    }
    
    @ObservedObject private var selectionState: SelectionState
    @EnvironmentObject var showSubToolbar: ShowSubToolbar
    @Binding private var selectedWebView: MarkupWKWebView?
    @Binding private var markupDelegate: MarkupDelegate?
    public var body: some View {
        if showSubToolbar.type == .link {
            LinkToolbar(selectionState: selectionState, selectedWebView: $selectedWebView)
                .onAppear {
                    markupDelegate?.markupToolbarAppeared(type: .link)
                }
                .onDisappear {
                    markupDelegate?.markupToolbarDisappeared()
                    selectedWebView?.becomeFirstResponder()
                }
        }
        if showSubToolbar.type == .image {
            ImageToolbar(selectionState: selectionState, selectedWebView: $selectedWebView)
                .onAppear {
                    markupDelegate?.markupToolbarAppeared(type: .image)
                }
                .onDisappear {
                    markupDelegate?.markupToolbarDisappeared()
                    selectedWebView?.becomeFirstResponder()
                }
            
        }
        if showSubToolbar.type == .table {
            TableToolbar(selectionState: selectionState, selectedWebView: $selectedWebView)
                .onAppear {
                    markupDelegate?.markupToolbarAppeared(type: .table)
                }
                .onDisappear {
                    markupDelegate?.markupToolbarDisappeared()
                    selectedWebView?.becomeFirstResponder()
                }
        }
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, markupDelegate: Binding<MarkupDelegate?>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        _markupDelegate = markupDelegate
    }
    
}
