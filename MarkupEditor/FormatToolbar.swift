//
//  FormatToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//

import SwiftUI

public struct FormatToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    
    public var body: some View {
        LabeledToolbar(label: Text("Format").font(.system(size: 10, weight: .light))) {
                ToolbarImageButton(
                    image: Image(systemName: "bold"),
                    action: { selectedWebView?.bold() },
                    active: selectionState.bold
                )
                ToolbarImageButton(
                    image: Image(systemName: "italic"),
                    action: { selectedWebView?.italic() },
                    active: selectionState.italic
                )
                ToolbarImageButton(
                    image: Image(systemName: "underline"),
                    action: { selectedWebView?.underline() },
                    active: selectionState.underline
                )
                ToolbarImageButton(
                    image: Image(systemName: "curlybraces"),
                    action: { selectedWebView?.code() },
                    active: selectionState.code
                )
                ToolbarImageButton(
                    image: Image(systemName: "strikethrough"),
                    action: { selectedWebView?.strike() },
                    active: selectionState.strike
                )
                ToolbarImageButton(
                    image: Image(systemName: "textformat.subscript"),
                    action: { selectedWebView?.subscriptText() },
                    active: selectionState.sub
                )
                ToolbarImageButton(
                    image: Image(systemName: "textformat.superscript"),
                    action: { selectedWebView?.superscript() },
                    active: selectionState.sup
                )
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
