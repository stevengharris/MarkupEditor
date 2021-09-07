//
//  LinkToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The toolbar for creating and editing hyperlinks.
public struct LinkToolbar: View {
    @EnvironmentObject var toolbarPreference: ToolbarPreference
    @Binding private var selectedWebView: MarkupWKWebView?
    @ObservedObject private var selectionState: SelectionState
    private var initialHref: String?
    // The href and link are the state for the toolbar
    @State private var href: String
    @State private var link: String
    // The previewed value holds on to what has been previewed, to
    // avoid doing the insert/modify unnecessarily
    @State private var previewedHref: String
    // The "arg" equivalent is to pass to insertLink
    private var argHRef: String? { href.isEmpty ? nil : href }
    
    public var body: some View {
        Group {
            switch toolbarPreference.style {
            case .compact:
                HStack(alignment: .center) {
                    GeometryReader { geometry in
                        HStack {
                            ToolbarTextField(
                                label: "Link URL",
                                placeholder: "Enter Link URL",
                                text: $href,
                                commitHandler: { save() },
                                validationHandler: { href.isValidURL }
                            )
                            .frame(width: geometry.size.width * 0.7)
                            ToolbarTextField(
                                label: "Text",
                                placeholder: "No linked text",
                                text: $link
                            )
                            .frame(width: geometry.size.width * 0.3)
                            .disabled(true)
                        }
                        .frame(height: geometry.size.height)
                    }
                    .padding([.trailing], 8)
                    Divider()
                    LabeledToolbar(label: Text("Delete")) {
                        ToolbarImageButton(
                                systemName: "link",
                                action: { selectedWebView?.insertLink(nil) }
                            ).overlay(
                                Image(systemName: "xmark")
                                    .foregroundColor(Color.red)
                                    .font(Font.system(size: 8).weight(.bold))
                                    .offset(CGSize(width: -(toolbarPreference.buttonHeight() / 2) + 6, height: (toolbarPreference.buttonHeight() / 2) - 6))
                                    .zIndex(1)
                            )
                    }
                    .disabled(!selectionState.isInLink)
                    Divider()
                    ToolbarTextButton(title: "Save", action: { self.save() }, width: 80)
                        .disabled(!canBeSaved())
                        .onTapGesture() {}  // Needed to recognize tap for ToolbarButtonStyle
                    ToolbarTextButton(title: "Cancel", action: { self.cancel() }, width: 80)
                        .onTapGesture() {}  // Needed to recognize tap for ToolbarButtonStyle
                }
                .frame(height: 28)
            case .labeled:
                HStack(alignment: .bottom) {
                    GeometryReader { geometry in
                        HStack {
                            ToolbarTextField(
                                label: "Link URL",
                                placeholder: "Enter Link URL",
                                text: $href,
                                commitHandler: { save() },
                                validationHandler: { href.isValidURL }
                            )
                            .frame(width: geometry.size.width * 0.7)
                            ToolbarTextField(
                                label: "Linked Text",
                                placeholder: "No linked text",
                                text: $link
                            )
                            .frame(width: geometry.size.width * 0.3)
                            .disabled(true)
                        }
                        .frame(height: geometry.size.height)
                    }
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 8))
                    Divider()
                    LabeledToolbar(label: Text("Delete")) {
                        ToolbarImageButton(
                            systemName: "link",
                            action: { selectedWebView?.insertLink(nil) }
                        ).overlay(
                            Image(systemName: "xmark")
                                .foregroundColor(Color.red)
                                .font(Font.system(size: 8).weight(.bold))
                                .offset(CGSize(width: -(toolbarPreference.buttonHeight() / 2) + 6, height: (toolbarPreference.buttonHeight() / 2) - 6))
                                .zIndex(1)
                        )
                    }
                    .padding([.bottom], 3)
                    .disabled(!selectionState.isInLink)
                    Divider()
                    ToolbarTextButton(title: "Save", action: { self.save() }, width: 80)
                        .padding([.bottom], 4)
                        .disabled(!canBeSaved())
                        .onTapGesture() {}  // Needed to recognize tap for ToolbarButtonStyle
                    ToolbarTextButton(title: "Cancel", action: { self.cancel() }, width: 80)
                        .padding([.bottom], 4)
                        .onTapGesture() {}  // Needed to recognize tap for ToolbarButtonStyle
                }
                .frame(height: 50)
            }
        }
        .onChange(of: selectionState.selection, perform: { value in
            print("Alink: ", (selectionState.link ?? "nil"), ", selection: ", (selectionState.selection ?? "nil"))
            href = selectionState.href ?? ""
            link = selectionState.link ?? selectionState.selection ?? ""
            previewedHref = href
        })
        .onChange(of: selectionState.href, perform: { value in
            print("Blink: ", (selectionState.link ?? "nil"), ", selection: ", (selectionState.selection ?? "nil"))
            href = selectionState.href ?? ""
            link = selectionState.link ?? selectionState.selection ?? ""
            previewedHref = href
        })
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Blur(style: .systemUltraThinMaterial))
        
    }
    
    private func canBeSaved() -> Bool {
        return (!href.isEmpty && href.isValidURL) || (href.isEmpty && initialHref != nil)
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        initialHref = selectionState.href
        _previewedHref = State(initialValue: selectionState.href ?? "")
        _href = State(initialValue: selectionState.href ?? "")
        _link = State(initialValue: selectionState.link ?? selectionState.selection ?? "")
    }
    
    private func previewed() -> Bool {
        // Return whether what we are seeing on the screen is the same as is in the toolbar
        return href == previewedHref
    }
    
    private func insertOrModify(handler: (()->Void)? = nil) {
        guard !previewed() else {
            handler?()
            return
        }
        if previewedHref.isEmpty && !href.isEmpty {
            selectedWebView?.insertLink(argHRef) {
                previewedHref = href
                handler?()
            }
        } else {
            selectedWebView?.insertLink(argHRef) {
                previewedHref = href
                handler?()
            }
        }
        
    }
    
    private func save() {
        // Save href it is hasn't been previewed, and then close
        guard canBeSaved() else { return }
        insertOrModify()
    }
    
    private func cancel() {
        // Restore href to its initial value, put things back the way they were, and then close
        href = initialHref ?? ""
        insertOrModify()
    }
    
}

struct LinkToolbar_Previews: PreviewProvider {
    static var previews: some View {
        LinkToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}
