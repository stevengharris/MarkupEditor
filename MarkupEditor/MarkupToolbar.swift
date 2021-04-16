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
public struct MarkupToolbar: View {
    
    public enum ToolbarType {
        case image
        case link
        case table
    }
    
    @Binding public var selectedWebView: MarkupWKWebView?
    @ObservedObject private var selectionState: SelectionState
    private var markupDelegate: MarkupDelegate?
    @State private var showToolbarByType: [ToolbarType : Bool] = [
        .image : false,
        .link: false,
        .table: false
    ]
    private var showLinkToolbar: Bool { showToolbarByType[.link] ?? false }
    private var showImageToolbar: Bool { showToolbarByType[.image] ?? false }
    private var showTableToolbar: Bool { showToolbarByType[.table] ?? false }
    /// User-supplied view to be shown on the left side of the default MarkupToolbar
    private var leftToolbar: AnyView?
    /// User-supplied view to be shown on the right side of the default MarkupToolbar
    private var rightToolbar: AnyView?
    
    public var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .bottom) {
                if leftToolbar != nil {
                    leftToolbar
                    Divider()
                }
                Group {
                    UndoRedoToolbar(selectionState: selectionState, selectedWebView: $selectedWebView)
                    Divider()
                    InsertToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbarByType: $showToolbarByType)
                    Divider()
                    StyleToolbar(selectionState: selectionState, selectedWebView: $selectedWebView)
                    Divider()
                    FormatToolbar(selectionState: selectionState, selectedWebView: $selectedWebView)
                    Divider()           // Vertical on the right
                }
                if rightToolbar != nil {
                    rightToolbar
                    Divider()
                }
                Spacer()            // Push everything to the left
            }
            .frame(height: 47)
            .padding([.leading, .trailing], 8)
            .padding([.top, .bottom], 2)
            .disabled(selectedWebView == nil)
            Divider()           // Horizontal at the bottom
            if showImageToolbar {
                ImageToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbar: showToolbarBinding(type: .image))
                    //.transition(.move(edge: .bottom))
                    .onAppear(perform: {
                        selectedWebView?.backupRange()
                        markupDelegate?.markupToolbarAppeared(type: .image)
                    })
                    .onDisappear(perform: {
                        markupDelegate?.markupToolbarDisappeared(type: .image)
                        selectedWebView?.becomeFirstResponder()
                    })
            }
            if showLinkToolbar {
                LinkToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbar: showToolbarBinding(type: .link))
                    //.transition(.move(edge: .bottom))
                    .onAppear(perform: {
                        selectedWebView?.backupRange()
                        markupDelegate?.markupToolbarAppeared(type: .link)
                    })
                    .onDisappear(perform: {
                        markupDelegate?.markupToolbarDisappeared(type: .link)
                        selectedWebView?.becomeFirstResponder()
                    })
            }
            if showTableToolbar {
                TableToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbar: showToolbarBinding(type: .table))
                    //.transition(.move(edge: .bottom))
                    .onAppear(perform: {
                        selectedWebView?.backupRange()
                        markupDelegate?.markupToolbarAppeared(type: .link)
                    })
                    .onDisappear(perform: {
                        markupDelegate?.markupToolbarDisappeared(type: .link)
                        selectedWebView?.becomeFirstResponder()
                    })
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(UIColor.systemBackground))
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, markupDelegate: MarkupDelegate? = nil, leftToolbar: AnyView? = nil, rightToolbar: AnyView? = nil) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        self.markupDelegate = markupDelegate
        self.leftToolbar = leftToolbar
        self.rightToolbar = rightToolbar
    }
    
    private func showToolbarBinding(type: ToolbarType) -> Binding<Bool> {
        return Binding(get: {showToolbarByType[type] ?? false}, set: { showToolbarByType[type] = $0 })
    }
    
}

//MARK:- Previews

struct MarkupToolbar_Previews: PreviewProvider {
    
    static var previews: some View {
        MarkupToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}


