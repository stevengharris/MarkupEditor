//
//  MarkupToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The MarkupToolbar acts on the selectedWebView and shows the current selectionState.
///
/// The MarkupToolbar observes the selectionState so that its display reflects the current state.
/// For example, when selectedWebView is nil, the toolbar is disabled, and when the selectionState shows
/// that the selection is inside of a bolded element, then the bold (B) button is active and filled-in.
///
/// An additional section of the toolbar is presented only when built in Debug mode.
public struct MarkupToolbar: View {
    
    typealias DisplayFormat = MarkupWKWebView.DisplayFormat
    public enum ToolbarType {
        case image
        case link
        case table
    }
    
    private let isDebug = _isDebugAssertConfiguration()
    @Binding public var selectedWebView: MarkupWKWebView?
    @ObservedObject private var selectionState: SelectionState
    private var markupUIDelegate: MarkupUIDelegate?
    // Note that the selectedFormat is kept locally here as @State, but can be set as
    // a result of the selectedWebView changing externally or as a result of the
    // Picker being used in this View
    @State private var selectedFormat: DisplayFormat = .Formatted
    @State private var showImageToolbar: Bool = false
    @State private var showLinkToolbar: Bool = false
    
    public var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .bottom) {
                InsertToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showImageToolbar: $showImageToolbar, showLinkToolbar: $showLinkToolbar)
                    .disabled(selectedFormat == .Raw)
                Divider()
                UndoRedoToolbar(selectionState: selectionState, selectedWebView: $selectedWebView)
                    .disabled(selectedFormat == .Raw)
                Divider()
                StyleToolbar(selectionState: selectionState, selectedWebView: $selectedWebView)
                    .disabled(selectedFormat == .Raw)
                Divider()
                FormatToolbar(selectionState: selectionState, selectedWebView: $selectedWebView)
                    .disabled(selectedFormat == .Raw)
                if isDebug {
                    DebugToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, selectedFormat: $selectedFormat)
                }
                Divider()       // Vertical on the right
                Spacer()
            }
            .frame(height: 47)
            .padding([.leading, .trailing], 8)
            .padding([.top, .bottom], 2)
            .disabled(selectedWebView == nil)
            Divider()           // Horizontal at the bottom
            if showImageToolbar {
                ImageToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbar: $showImageToolbar)
                    //.transition(.move(edge: .bottom))
                    .onAppear(perform: {
                        selectedWebView?.backupRange()
                        markupUIDelegate?.markupToolbarAppeared(type: .image)
                    })
                    .onDisappear(perform: {
                        markupUIDelegate?.markupToolbarDisappeared(type: .image)
                        selectedWebView?.becomeFirstResponder()
                    })
            }
            if showLinkToolbar {
                LinkToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbar: $showLinkToolbar)
                    //.transition(.move(edge: .bottom))
                    .onAppear(perform: {
                        selectedWebView?.backupRange()
                        markupUIDelegate?.markupToolbarAppeared(type: .link)
                    })
                    .onDisappear(perform: {
                        markupUIDelegate?.markupToolbarDisappeared(type: .link)
                        selectedWebView?.becomeFirstResponder()
                    })
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(UIColor.systemBackground))
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, markupUIDelegate: MarkupUIDelegate? = nil) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        // Note if markupUIDelegate is not specified, no insert operation alerts will be shown
        self.markupUIDelegate = markupUIDelegate
    }
    
}

//MARK:- Previews

struct MarkupToolbar_Previews: PreviewProvider {
    
    static var previews: some View {
        MarkupToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}


