//
//  FormatToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//

import SwiftUI

struct FormatToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    
    var body: some View {
        VStack(spacing: 2) {
            Text("Format")
                .font(.system(size: 10, weight: .light))
            HStack(alignment: .bottom) {
                Group {
                    ToolbarImageButton(
                        image: Image(systemName: "bold"),
                        action: { selectedWebView?.bold() },
                        active: selectionState.bold
                    )
                    .id(UUID())
                    ToolbarImageButton(
                        image: Image(systemName: "italic"),
                        action: { selectedWebView?.italic() },
                        active: selectionState.italic
                    )
                    .id(UUID())
                    ToolbarImageButton(
                        image: Image(systemName: "underline"),
                        action: { selectedWebView?.underline() },
                        active: selectionState.underline
                    )
                    .id(UUID())
                    ToolbarImageButton(
                        image: Image(systemName: "curlybraces"),
                        action: { selectedWebView?.code() },
                        active: selectionState.code
                    )
                    .id(UUID())
                    ToolbarImageButton(
                        image: Image(systemName: "strikethrough"),
                        action: { selectedWebView?.strike() },
                        active: selectionState.strike
                    )
                    .id(UUID())
                    ToolbarImageButton(
                        image: Image(systemName: "textformat.subscript"),
                        action: { selectedWebView?.subscriptText() },
                        active: selectionState.sub
                    )
                    .id(UUID())
                    ToolbarImageButton(
                        image: Image(systemName: "textformat.superscript"),
                        action: { selectedWebView?.superscript() },
                        active: selectionState.sup
                    )
                    .id(UUID())
                }
            }
        }
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
    }
}

struct FormatToolbar_Previews: PreviewProvider {
    static var previews: some View {
        FormatToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}
