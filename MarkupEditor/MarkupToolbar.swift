//
//  MarkupToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The MarkupToolbar shows the current selectionState and acts on the selectedWebView held
/// by the observedWebView.
///
/// The MarkupToolbar observes the selectionState so that its display reflects the current state.
/// For example, when selectedWebView is nil, the toolbar is disabled, and when the selectionState shows
/// that the selection is inside of a bolded element, then the bold (B) button is active and filled-in.
/// The MarkupToolbar contains multiple other toolbars, such as StyleToolbar and FormatToolbar
/// which invoke methods in the selectedWebView, an instance of MarkupWKWebView.
/// The InsertToolbar sets showSubToolbar.type, which in turn uncovers one of the specific
/// subtoolbars that require additional user interaction.
public struct MarkupToolbar: View {
    public let toolbarStyle: ToolbarStyle
    private let withKeyboardButton: Bool
    public let withSubToolbar: Bool         // Set to false by MarkupToolbarUIView
    public let subToolbarEdge: Edge
    @ObservedObject private var observedWebView = MarkupEditor.observedWebView
    @ObservedObject private var selectionState = MarkupEditor.selectionState
    @ObservedObject public var showSubToolbar: ShowSubToolbar = ShowSubToolbar()
    private var contents: ToolbarContents
    public var markupDelegate: MarkupDelegate?
    private var subToolbarOffset: CGFloat { subToolbarEdge == .bottom ? toolbarStyle.height() : -toolbarStyle.height() }
    
    public var body: some View {
        //if #available(macCatalyst 15.0, *) {
        //    let _ = Self._printChanges()
        //}
        let bottomSubToolbar = withSubToolbar && subToolbarEdge == .bottom && showSubToolbar.type != .none
        let topSubToolbar = withSubToolbar && subToolbarEdge == .top && showSubToolbar.type != .none
        ZStack(alignment: .topLeading) {
            if topSubToolbar { SubToolbar(for: self).offset(y: subToolbarOffset) }
            HStack {
                ScrollView(.horizontal) {
                    HStack {
                        if contents.leftToolbar {
                            MarkupEditor.leftToolbar!
                        }
                        if contents.correction {
                            if contents.leftToolbar { Divider() }
                            CorrectionToolbar()
                        }
                        if contents.insert {
                            if contents.leftToolbar || contents.correction { Divider() }
                            InsertToolbar(for: self)        // for: self because it uses the SubToolbar
                        }
                        if contents.style {
                            if contents.leftToolbar || contents.correction  || contents.insert { Divider() }
                            StyleToolbar()
                        }
                        if contents.format {
                            if contents.leftToolbar || contents.correction  || contents.insert || contents.style { Divider() }
                            FormatToolbar()
                        }
                        if contents.rightToolbar {
                            if contents.leftToolbar || contents.correction  || contents.insert || contents.style || contents.format { Divider() }
                            MarkupEditor.rightToolbar!
                        }
                        Spacer()                // Push everything to the left
                    }
                    .environmentObject(toolbarStyle)
                    .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    .disabled(observedWebView.selectedWebView == nil || !selectionState.valid)
                }
                .onTapGesture {}    // To make the buttons responsive inside of the ScrollView
                if withKeyboardButton {
                    Spacer()
                    Divider()
                    ToolbarImageButton(
                        systemName: "keyboard.chevron.compact.down",
                        action: {
                            showSubToolbar.type = .none
                            _ = MarkupEditor.selectedWebView?.resignFirstResponder()
                        }
                    )
                    Spacer()
                }
            }
            if bottomSubToolbar { SubToolbar(for: self).offset(y: subToolbarOffset) }
        }
        .frame(height: MarkupEditor.toolbarStyle.height())
        .zIndex(999)
    }
    
    public init(_ style: ToolbarStyle.Style? = nil, contents: ToolbarContents? = nil, markupDelegate: MarkupDelegate? = nil, withKeyboardButton: Bool = false, withSubToolbar: Bool = true, subToolbarEdge: Edge = .bottom) {
        let toolbarStyle = style == nil ? MarkupEditor.toolbarStyle : ToolbarStyle(style!)
        self.toolbarStyle = toolbarStyle
        let toolbarContents = contents == nil ? MarkupEditor.toolbarContents : contents!
        self.contents = toolbarContents
        self.withKeyboardButton = withKeyboardButton
        self.withSubToolbar = withSubToolbar
        self.subToolbarEdge = subToolbarEdge
        self.markupDelegate = markupDelegate
    }

}

//MARK: Previews

struct MarkupToolbar_Previews: PreviewProvider {
    
    static var previews: some View {
        VStack(alignment: .leading) {
            MarkupToolbar(.compact)
            MarkupToolbar(.labeled)
            Spacer()
        }
        .onAppear {
            MarkupEditor.selectedWebView = MarkupWKWebView()
            MarkupEditor.selectionState.valid = true
        }
    }
}


