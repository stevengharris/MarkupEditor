//
//  SubToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 6/27/21.
//

import SwiftUI

/// The sub-toolbar used for creating/editing links, images, and tables.
public struct SubToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    @Binding private var markupDelegate: MarkupDelegate?
    @Binding private var showLinkToolbar: Bool
    @Binding private var showImageToolbar: Bool
    @Binding private var showTableToolbar: Bool
    public var body: some View {
        if showLinkToolbar {
            LinkToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbar: $showLinkToolbar)
                .onAppear {
                    markupDelegate?.markupToolbarAppeared(type: .link)
                }
                .onDisappear {
                    markupDelegate?.markupToolbarDisappeared()
                    selectedWebView?.becomeFirstResponder()
                }
        }
        if showImageToolbar {
            ImageToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbar: $showImageToolbar)
                .onAppear {
                    markupDelegate?.markupToolbarAppeared(type: .image)
                }
                .onDisappear {
                    markupDelegate?.markupToolbarDisappeared()
                    selectedWebView?.becomeFirstResponder()
                }
            
        }
        if showTableToolbar {
            TableToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbar: $showTableToolbar)
                .onAppear {
                    markupDelegate?.markupToolbarAppeared(type: .table)
                }
                .onDisappear {
                    markupDelegate?.markupToolbarDisappeared()
                    selectedWebView?.becomeFirstResponder()
                }
        }
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, markupDelegate: Binding<MarkupDelegate?>, showLinkToolbar: Binding<Bool>, showImageToolbar: Binding<Bool>, showTableToolbar: Binding<Bool>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        _markupDelegate = markupDelegate
        _showLinkToolbar = showLinkToolbar
        _showImageToolbar = showImageToolbar
        _showTableToolbar = showTableToolbar
    }
    
}
