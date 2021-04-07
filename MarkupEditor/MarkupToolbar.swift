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
    
    private let isDebug = _isDebugAssertConfiguration()
    @Binding public var selectedWebView: MarkupWKWebView?
    @ObservedObject private var selectionState: SelectionState
    private var markupUIDelegate: MarkupUIDelegate?
    // Note that the selectedFormat is kept locally here as @State, but can be set as
    // a result of the selectedWebView changing externally or as a result of the
    // Picker being used in this View
    @State private var selectedFormat: DisplayFormat = .Formatted
    //@State private var markupAlert: MarkupAlert?
    @State private var showImageToolbar: Bool = false
    
    public var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .bottom) {
                MarkupInsertToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showImageToolbar: $showImageToolbar)
                    .disabled(selectedFormat == .Raw)
                Divider()
                VStack(spacing: 2) {
                    Text("Undo/Redo")
                        .font(.system(size: 10, weight: .light))
                    HStack(alignment: .bottom) {
                        ToolbarImageButton(
                            image: Image(systemName: "arrow.uturn.backward"),
                            action: { print("markupView?.undo()") }
                        )
                        .id(UUID())
                        ToolbarImageButton(
                            image:  Image(systemName: "arrow.uturn.forward"),
                            action: { print("markupView?.redo()") }
                        )
                        .id(UUID())
                    }
                }
                .disabled(selectedFormat == .Raw)
                Divider()
                VStack(spacing: 2) {
                    Text("Style")
                        .font(.system(size: 10, weight: .light))
                    HStack(alignment: .bottom) {
                        // I spent a long time trying to make the drop-down buttons show in the proper font.
                        // AFAICT, Apple is doing something aggressive to prevent that from happening.
                        // Maybe it messes something up on MacOS. OTOH, I see it on OneNote as a kind of
                        // tooltip-looking thing. I suppose the only way to work around it for now would
                        // be to build it myself and not use Menu. OTOH, even labels with icons don't work
                        // on Catalyst, so it just seems too much like fighting a battle.
                        // Currently this menu right-justifies in a fixed width.
                        // The build needs to use "Scale Interface to Match iPad" for the menu to appear
                        // properly. If "Optimize Interface for Mac" is used, then the Menu has a drop-down
                        // arrow next to it and ends up with a weird outline-within-outline look because of
                        // the ToolbarMenuStyle.
                        Menu {
                            ForEach(StyleContext.StyleCases.filter( { $0 != selectionState.style }) , id: \.self) { styleContext in
                                Button(action: { selectedWebView?.replaceStyle(in: selectionState, with: styleContext) }) {
                                    Text(styleContext.name)
                                        .font(.system(size: styleContext.fontSize))
                                }
                            }
                        } label: {
                            Text(selectionState.style.name)
                                .frame(width: 88, height: 20, alignment: .center)
                        }
                        .frame(width: 88, height: 30)
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: 3,
                                style: .continuous
                            )
                            .stroke(Color.accentColor)
                        )
                        .disabled(selectionState.style == .Undefined)
                        Divider()
                        ToolbarImageButton(
                            image: Image(systemName: "list.bullet"),
                            action: { selectedWebView?.toggleListItem(type: .UL) },
                            active: selectionState.isInListItem && selectionState.list == .UL
                        )
                        .id(UUID())
                        ToolbarImageButton(
                            image: Image(systemName: "list.number"),
                            action: { selectedWebView?.toggleListItem(type: .OL) },
                            active: selectionState.isInListItem && selectionState.list == .OL
                        )
                        .id(UUID())
                        ToolbarImageButton(
                            image: Image(systemName: "increase.quotelevel"),
                            action: { selectedWebView?.increaseQuoteLevel() },
                            active: selectionState.quote
                        )
                        .id(UUID())
                        ToolbarImageButton(
                            image: Image(systemName: "decrease.quotelevel"),
                            action: { selectedWebView?.decreaseQuoteLevel() },
                            active: selectionState.quote
                        )
                        .id(UUID())
                        .disabled(!selectionState.quote)
                    }
                }
                .disabled(selectedFormat == .Raw)
                Divider()
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
                .disabled(selectedFormat == .Raw)
                if isDebug {
                    Group {
                        Divider()
                        VStack(spacing: 2) {
                            Text("Debug")
                                .font(.system(size: 10, weight: .light))
                            HStack(alignment: .bottom) {
                                Picker(selection: $selectedFormat, label: Text("")) {
                                    ForEach(DisplayFormat.allCases, id: \.self) {
                                        Text($0.rawValue)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .onChange(of: selectedFormat, perform: { format in
                                    selectedWebView?.showAs(format)
                                })
                                .onChange(of: selectedWebView, perform: { webView in
                                    selectedFormat = selectedWebView?.selectedFormat ?? .Formatted
                                })
                            }
                            .scaledToFit()
                        }
                    }
                }
                Divider()       // Vertical on the right
                Spacer()
            }
            .padding([.leading, .trailing], 8)
            .padding([.top], 2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(idealHeight: 54, maxHeight: 54)
            .disabled(selectedWebView == nil)
            Divider()           // Horizontal at the bottom
            if showImageToolbar {
                MarkupImageToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showImageToolbar: $showImageToolbar)
                    //.transition(.move(edge: .bottom))
                    .onAppear(perform: {
                        selectedWebView?.backupRange()
                        markupUIDelegate?.markupImageToolbarAppeared()
                    })
                    .onDisappear(perform: {
                        markupUIDelegate?.markupImageToolbarDisappeared()
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
    
    //private func showAlert(type: MarkupAlertType) {
    //    guard let delegate = markupUIDelegate else { return }
    //    delegate.markupInsert(selectedWebView, type: type, selectionState: selectionState) { error in
    //        guard error == nil else { return }
    //        markupAlert = MarkupAlert(type: type)
    //    }
    //}
    
    //private func createTextAlert() -> TextAlert {
    //    guard let delegate = markupUIDelegate, let type = markupAlert?.type else {
    //        return TextAlert(title: "Error", action: { _, _ in } )
    //    }
    //    return delegate.markupTextAlert(selectedWebView, type: type, selectionState: selectionState)
    //}
    
}

//MARK:- Previews

struct MarkupToolbar_Previews: PreviewProvider {
    
    static var previews: some View {
        MarkupToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}


