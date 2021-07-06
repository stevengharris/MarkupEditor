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
/// The MarkupToolbar contains multiple other toolbars, such as StyleToolbar and FormatToolbar
/// which invoke methods in the selectedWebView, an instance of MarkupWKWebView.
/// The InsertToolbar sets showSubToolbar.type, which in turn uncovers one of the specific
/// subtoolbars that require additional user interaction.
public struct MarkupToolbar: View {
    @Binding public var selectedWebView: MarkupWKWebView?
    @ObservedObject private var selectionState: SelectionState
    @State var markupDelegate: MarkupDelegate?
    /// User-supplied view to be shown on the left side of the default MarkupToolbar
    private var leftToolbar: AnyView?
    /// User-supplied view to be shown on the right side of the default MarkupToolbar
    private var rightToolbar: AnyView?
    
    public var body: some View {
        
        ScrollView(.horizontal) {
            VStack(spacing: 2) {
                HStack(alignment: .bottom) {
                    if leftToolbar != nil {
                        leftToolbar
                        Divider()
                    }
                    Group {
                        CorrectionToolbar(selectionState: selectionState, selectedWebView: $selectedWebView)
                        Divider()
                        InsertToolbar(selectionState: selectionState, selectedWebView: $selectedWebView)
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
                    Spacer()                // Push everything to the left
                }
                .frame(height: 47)
                .padding([.leading, .trailing], 8)
                .padding([.top, .bottom], 2)
                .disabled(selectedWebView == nil)
                Divider()                   // Horizontal at the bottom
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(UIColor.systemBackground))
        }
        .onTapGesture {}    // Otherwise, the MarkupToolbar ToolbarButtons end up not working when in the ScrollView.
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, markupDelegate: MarkupDelegate? = nil, leftToolbar: AnyView? = nil, rightToolbar: AnyView? = nil) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        self.markupDelegate = markupDelegate
        self.leftToolbar = leftToolbar
        self.rightToolbar = rightToolbar
    }
    
}

//MARK:- Previews

struct MarkupToolbar_Previews: PreviewProvider {
    
    static var previews: some View {
        MarkupToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}


