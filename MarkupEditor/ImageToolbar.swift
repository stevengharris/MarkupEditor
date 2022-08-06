//
//  ImageToolbar.swift
//  MarkupEditor
//  
//  Created by Steven Harris on 3/24/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The toolbar for creating and editing images.
public struct ImageToolbar: View {
    @EnvironmentObject private var markupEnv: MarkupEnv
    @EnvironmentObject private var toolbarPreference: ToolbarPreference
    @EnvironmentObject private var observedWebView: ObservedWebView
    @EnvironmentObject private var selectionState: SelectionState
    @EnvironmentObject private var selectImage: SelectImage
    private var allowLocalImages: Bool { markupEnv.allowLocalImages }
    private var height: CGFloat { toolbarPreference.height() }
    private var initialSrc: String?
    private var initialAlt: String?
    // The src and alt values are the state for the toolbar
    @State private var src: String
    @State private var alt: String
    // The previewed values hold on to what has been previewed, to
    // avoid doing the insert/modify unnecessarily
    @State private var previewedSrc: String
    @State private var previewedAlt: String
    // The "arg" equivalent is for scale passed to create/modifyImage
    private var argSrc: String? { src.isEmpty ? nil : src }
    private var argAlt: String? { alt.isEmpty ? nil : alt }
    @State private var saving: Bool = false
    @State private var endedEditing: Bool = false
    @State private var focusedField = "src"
    
    public var body: some View {
        Group {
            switch toolbarPreference.style {
            case .compact:
                HStack(alignment: .center) {
                    GeometryReader { geometry in
                        HStack {
                            ToolbarTextField(
                                label: "Image URL",
                                placeholder: "Enter Image URL",
                                text: $src,
                                commitHandler: { save("src") },
                                takeFocusOn: "src",
                                focusIsOn: $focusedField
                            )
                            .frame(width: geometry.size.width * 0.7)
                            ToolbarTextField(
                                label: "Description",
                                placeholder: "Enter Description",
                                text: $alt,
                                commitHandler: { save("alt") },
                                takeFocusOn: "alt",
                                focusIsOn: $focusedField
                            )
                            .frame(width: geometry.size.width * 0.3)
                        }
                        .frame(height: geometry.size.height)
                    }
                    .padding([.trailing], 8)
                    if allowLocalImages {
                        ToolbarTextButton(title: "Select", action: { selectImage.value = true }) //, width: 50)
                            .onTapGesture() {}  // Needed to recognize tap for ToolbarButtonStyle
                    }
                }
                .frame(height: height)
            case .labeled:
                HStack(alignment: .bottom) {
                    GeometryReader { geometry in
                        HStack {
                            ToolbarTextField(
                                label: "Image URL",
                                placeholder: "Enter Image URL",
                                text: $src,
                                commitHandler: { save("src") },
                                takeFocusOn: "src",
                                focusIsOn: $focusedField
                            )
                            .frame(width: geometry.size.width * 0.7)
                            ToolbarTextField(
                                label: "Description",
                                placeholder: "Enter Description",
                                text: $alt,
                                commitHandler: { save("alt") },
                                takeFocusOn: "alt",
                                focusIsOn: $focusedField
                            )
                            .frame(width: geometry.size.width * 0.3)
                        }
                        .padding([.top], 2)
                    }
                    .padding([.trailing], 8)
                    if allowLocalImages {
                        ToolbarTextButton(title: "Select", action: { selectImage.value = true }) //, width: 50)
                            .onTapGesture() {}  // Needed to recognize tap for ToolbarButtonStyle
                    }
                }
                .frame(height: height)
            }
        }
        .onChange(of: selectionState.src, perform: { value in
            src = selectionState.src ?? ""
            alt = selectionState.alt ?? ""
            previewedSrc = src
            previewedAlt = alt
        })
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Blur(style: .systemUltraThinMaterial))
        .disabled(observedWebView.selectedWebView == nil || !selectionState.valid)
    }
    
    public init(selectionState: SelectionState) {
        initialSrc = selectionState.src
        initialAlt = selectionState.alt
        _previewedSrc = State(initialValue: selectionState.src ?? "")
        _previewedAlt = State(initialValue: selectionState.alt ?? "")
        _src = State(initialValue: selectionState.src ?? "")
        _alt = State(initialValue: selectionState.alt ?? "")
    }
    
    private func previewed() -> Bool {
        // Return whether what we are seeing on the screen is the same as is in the toolbar
        return src == previewedSrc && alt == previewedAlt
    }
    
    private func insertOrModify(handler: (()->Void)? = nil) {
        guard !previewed() else {
            handler?()
            return
        }
        if previewedSrc.isEmpty && !src.isEmpty {
            observedWebView.selectedWebView?.insertImage(src: argSrc, alt: argAlt) {
                previewedSrc = src
                previewedAlt = alt
                handler?()
            }
        } else {
            observedWebView.selectedWebView?.modifyImage(src: argSrc, alt: argAlt, scale: nil) {
                previewedSrc = src
                previewedAlt = alt
                handler?()
            }
        }
    }
    
    private func preview() {
        // The onChange event can fire and cause preview during the save operation.
        // So, if we are saving, then never preview.
        guard !saving else { return }
        insertOrModify()
    }
    
    private func save(_ fieldName: String) {
        // Insert or modify the image, then change the focusedField
        saving = true
        insertOrModify()
        focusedField = (fieldName == "src") ? "alt" : "src"
    }
    
}

struct ImageToolbar_Previews: PreviewProvider {
    static var previews: some View {
        let selectionState = SelectionState()
        let compactMarkupEnv = MarkupEnv(style: .compact, allowLocalImages: true)
        let compactPreference = compactMarkupEnv.toolbarPreference
        let labeledMarkupEnv = MarkupEnv(style: .labeled, allowLocalImages: true)
        let labeledPreference = labeledMarkupEnv.toolbarPreference
        VStack(alignment: .leading) {
            HStack {
                ImageToolbar(selectionState: selectionState)
                    .environmentObject(selectionState)
                    .environmentObject(compactPreference)
                    .frame(height: compactPreference.height())
                Spacer()
            }
            HStack {
                ImageToolbar(selectionState: selectionState)
                    .environmentObject(selectionState)
                    .environmentObject(labeledPreference)
                    .frame(height: labeledPreference.height())
                Spacer()
            }
            Spacer()
        }
    }
}
