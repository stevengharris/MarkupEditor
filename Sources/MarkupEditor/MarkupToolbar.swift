//
//  MarkupToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The MarkupToolbar acts on the selectedWebView and shows the current selectionState for it.
///
/// The MarkupToolbar observes the markupStateHolder so that its display reflects the current state.
/// For example, when selectedWebView is nil, the toolbar is disabled, and when the selectionState shows
/// that the selection is inside of a bolded element, then the bold (B) button is active and filled-in.
///
/// An additional section of the toolbar is presented only when built in Debug mode.
public struct MarkupToolbar<StateHolder>: View where StateHolder: MarkupStateHolder {
    
    typealias DisplayFormat = MarkupWKWebView.DisplayFormat
    
    /// A ButtonStyle that fills-in or outlines depending on what active is set to. Filled-in indicates active is true.
    /// The type of alerts that can be shown by the MarkupToolbar, primarily for insert operations
    struct ToolbarButtonStyle: ButtonStyle {
        var active: Bool = false
        
        func makeBody(configuration: Configuration) -> some View {
            // Fill the button when active; else outline in accent color
            configuration.label
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(
                        cornerRadius: 3,
                        style: .continuous
                    )
                    .stroke(Color.accentColor)
                    .background(active ? Color.accentColor : Color(UIColor.systemBackground))
                )
                .foregroundColor(active ? Color(UIColor.systemBackground) : Color.accentColor)
        }

    }

    /// A MenuStyle with a RoundedRectangle surrounding it, to match the ToolbarButtonStyle
    struct ToolbarMenuStyle: MenuStyle {
        
        func makeBody(configuration: Configuration) -> some View {
            // Fill the button when active; else outline in accent color
            // Use overlay for the outline, and since we only use this menu
            // for style, it is always set to the current style or disabled,
            // so no need to deal with active.
            Menu(configuration)
                .frame(width: 88, height: 28)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 3,
                        style: .continuous
                    )
                    .stroke(Color.accentColor)
                )
        }

    }

    private let isDebug = _isDebugAssertConfiguration()
    @ObservedObject private var markupStateHolder: StateHolder
    private var selectedWebView: MarkupWKWebView? { markupStateHolder.selectedWebView }
    private var selectionState: SelectionState { markupStateHolder.selectionState }
    private var markupUIDelegate: MarkupUIDelegate?
    // Note that the selectedFormat is kept locally here as @State, but can be set as
    // a result of the selectedWebView changing externally or as a result of the
    // Picker being used in this View
    @State private var selectedFormat: DisplayFormat = .Formatted
    @State private var markupAlert: MarkupAlert?
    
    public var body: some View {
        VStack(spacing: 4) {
            HStack {
                VStack(spacing: 2) {
                    Text("Insert")
                        .font(.system(size: 10, weight: .light))
                    HStack {
                        Button(action: {
                            showAlert(type: .link)
                        }) {
                            Image(systemName: "link")
                        }
                        .disabled(!selectionState.isLinkable)
                        Button(action: {
                            showAlert(type: .image)
                        }) {
                            Image(systemName: "photo")
                        }
                        .disabled(!selectionState.isInsertable && !selectionState.isInImage)
                        Button(action: {
                            showAlert(type: .line)
                        }) {
                            Image(systemName: "line.horizontal.3")
                        }
                        .disabled(!selectionState.isInsertable)
                        Button(action: {
                            showAlert(type: .table)
                        }) {
                            Image(systemName: "tablecells")
                        }
                        .disabled(!selectionState.isInsertable)
                        Button(action: {
                            showAlert(type: .sketch)
                        }) {
                            Image(systemName: "scribble")
                        }
                        .disabled(!selectionState.isInsertable)
                        Button(action: {
                            showAlert(type: .codeblock)
                        }) {
                            Image(systemName: "curlybraces")
                        }
                        .disabled(!selectionState.isInsertable)
                    }
                }
                .disabled(selectedFormat == .Raw)
                Divider()
                VStack(spacing: 2) {
                    Text("")
                        .font(.system(size: 10, weight: .light))
                    HStack(alignment: .bottom) {
                        Button(action: { print("markupView?.undo()") }) {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        Button(action: { print("markupView?.redo()") }) {
                            Image(systemName: "arrow.uturn.forward")
                        }
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
                        .menuStyle(ToolbarMenuStyle())
                        .frame(minWidth: 88, idealWidth: 88, alignment: .trailing)
                        .disabled(selectionState.style == .Undefined)
                        Divider()
                        Group {
                            Button(action: { selectedWebView?.toggleListItem(type: .UL) }) {
                                Image(systemName: "list.bullet")
                            }
                            .buttonStyle(ToolbarButtonStyle(active: selectionState.isInListItem && selectionState.list == .UL))
                            Button(action: { selectedWebView?.toggleListItem(type: .OL) }) {
                                Image(systemName: "list.number")
                            }
                            .buttonStyle(ToolbarButtonStyle(active: selectionState.isInListItem && selectionState.list == .OL))
                            Button(action: { selectedWebView?.increaseQuoteLevel() }) {
                                Image(systemName: "increase.quotelevel")
                            }
                            .buttonStyle(ToolbarButtonStyle(active: selectionState.quote))
                            Button(action: { selectedWebView?.decreaseQuoteLevel() }) {
                                Image(systemName: "decrease.quotelevel")
                            }
                            .buttonStyle(ToolbarButtonStyle(active: selectionState.quote))
                            .disabled(!selectionState.quote)
                        }
                    }
                }
                .disabled(selectedFormat == .Raw)
                Divider()
                VStack(spacing: 2) {
                    Text("Format")
                        .font(.system(size: 10, weight: .light))
                    HStack(alignment: .bottom) {
                        Group {
                            Button(action: { selectedWebView?.bold() }) {
                                Image(systemName: "bold")
                            }
                            .buttonStyle(ToolbarButtonStyle(active: selectionState.bold))
                            Button(action: { selectedWebView?.italic() }) {
                                Image(systemName: "italic")
                            }
                            .buttonStyle(ToolbarButtonStyle(active: selectionState.italic))
                            Button(action: { selectedWebView?.underline() }) {
                                Image(systemName: "underline")
                            }
                            .buttonStyle(ToolbarButtonStyle(active: selectionState.underline))
                            Button(action: { selectedWebView?.code() }) {
                                Image(systemName: "curlybraces")
                            }
                            .buttonStyle(ToolbarButtonStyle(active: selectionState.code))
                            Button(action: { selectedWebView?.strike() }) {
                                Image(systemName: "strikethrough")
                            }
                            .buttonStyle(ToolbarButtonStyle(active: selectionState.strike))
                            Button(action: { selectedWebView?.subscriptText() }) {
                                Image(systemName: "textformat.subscript")
                            }
                            .buttonStyle(ToolbarButtonStyle(active: selectionState.sub))
                            Button(action: { selectedWebView?.superscript() }) {
                                Image(systemName: "textformat.superscript")
                            }
                            .buttonStyle(ToolbarButtonStyle(active: selectionState.sup))
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
            Divider()           // Horizontal at the bottom
        }
        .alert(item: $markupAlert, createTextAlert())
        .disabled(selectedWebView == nil)
        .frame(idealHeight: 50, maxHeight: 50)
        .background(Color(UIColor.systemBackground))
    }
    
    public init(markupStateHolder: StateHolder, markupUIDelegate: MarkupUIDelegate? = nil) {
        // Note if markupUIDelegate is not specified, no insert operation alerts will be shown
        self.markupStateHolder = markupStateHolder
        self.markupUIDelegate = markupUIDelegate
    }
    
    private func showAlert(type: MarkupAlertType) {
        guard let delegate = markupUIDelegate else { return }
        delegate.markupInsert(selectedWebView, type: type, selectionState: selectionState) { error in
            guard error == nil else { return }
            markupAlert = MarkupAlert(type: type)
        }
    }
    
    private func createTextAlert() -> TextAlert {
        guard let delegate = markupUIDelegate, let type = markupAlert?.type else {
            return TextAlert(title: "Error", action: { _, _ in } )
        }
        return delegate.markupTextAlert(selectedWebView, type: type, selectionState: selectionState)
    }
    
}

//MARK:- Previews

struct MarkupToolbar_Previews: PreviewProvider {
    
    private class MockStateHolder: MarkupStateHolder {
        var selectedWebView: MarkupWKWebView? = nil
        var selectionState: SelectionState = SelectionState()
    }
    
    static var previews: some View {
        MarkupToolbar(markupStateHolder: MockStateHolder())
    }
}


