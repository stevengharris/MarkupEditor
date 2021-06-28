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
    @Binding private var selectedWebView: MarkupWKWebView?
    @ObservedObject private var selectionState: SelectionState
    private var initialSrc: String?
    private var initialAlt: String?
    private var initialScale: Int?
    private let scaleStep: Int = 5
    // The src, alt, and scale values are the state for the toolbar
    @State private var src: String
    @State private var alt: String
    @State private var scale: Int
    // The previewed values hold on to what has been previewed, to
    // avoid doing the insert/modify unnecessarily
    @State private var previewedSrc: String
    @State private var previewedAlt: String
    @State private var previewedScale: Int
    // The "arg" equivalent is for scale passed to create/modifyImage
    private var argSrc: String? { src.isEmpty ? nil : src }
    private var argAlt: String? { alt.isEmpty ? nil : alt }
    private var argScale: Int? { scale == 100 ? nil : scale }
    @State private var saving: Bool = false
    @State private var endedEditing: Bool = false
    
    public var body: some View {
        HStack(alignment: .bottom) {
            GeometryReader { geometry in
                HStack {
                    ToolbarTextField(
                        label: "Image URL",
                        placeholder: "Enter URL",
                        text: $src,
                        commitHandler: { save() },
                        validationHandler: { src.isValidURL }
                    )
                    .frame(width: geometry.size.width * 0.7)
                    ToolbarTextField(
                        label: "Description",
                        placeholder: "Enter Description",
                        text: $alt
                    )
                    .frame(width: geometry.size.width * 0.3)
                }
                .padding([.top], 2)
            }
            .padding([.trailing], 8)
            Divider()
            LabeledToolbar(label: Text("Scale")) {
                Stepper(onIncrement: incrementScale, onDecrement: decrementScale) {
                    Text("\(scale)%")
                        .frame(width: 50, alignment: .trailing)
                }
                .scaledToFit()
            }
            Divider()
            ToolbarTextButton(title: "Save", action: { self.save() }, width: 80)
                .disabled(!src.isEmpty && !src.isValidURL)
            ToolbarTextButton(title: "Cancel", action: { self.cancel() }, width: 80)
        }
        .onChange(of: selectionState.src, perform: { value in
            src = selectionState.src ?? ""
            alt = selectionState.alt ?? ""
            scale = selectionState.scale ?? 100
            previewedSrc = src
            previewedAlt = alt
            previewedScale = scale
        })
        .frame(height: 47)
        .padding([.leading, .trailing], 8)
        .padding([.top, .bottom], 2)
        Divider()
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        initialSrc = selectionState.src
        initialAlt = selectionState.alt
        initialScale = selectionState.scale
        _previewedSrc = State(initialValue: selectionState.src ?? "")
        _previewedAlt = State(initialValue: selectionState.alt ?? "")
        _previewedScale = State(initialValue: selectionState.scale ?? 100)
        _src = State(initialValue: selectionState.src ?? "")
        _alt = State(initialValue: selectionState.alt ?? "")
        _scale = State(initialValue: selectionState.scale ?? 100)
    }
    
    private func incrementScale() {
        // We need to reset scale and then set it back to avoid this bug:
        // https://stackoverflow.com/questions/58960251/strange-behavior-of-stepper-in-swiftui
        scale += scaleStep
        if scale > 100 {
            scale = 100
        } else {
            guard let view = selectedWebView, argSrc != nil else {
                scale -= scaleStep
                return
            }
            view.modifyImage(src: argSrc, alt: argAlt, scale: argScale, handler: nil)
        }
    }
    
    private func decrementScale() {
        // We need to reset scale and then set it back to avoid this bug:
        // https://stackoverflow.com/questions/58960251/strange-behavior-of-stepper-in-swiftui
        scale -= scaleStep
        if scale < scaleStep {
            scale = scaleStep
        } else {
            guard let view = selectedWebView, argSrc != nil else {
                scale += scaleStep
                return
            }
            view.modifyImage(src: argSrc, alt: argAlt, scale: argScale, handler: nil)
        }
    }
    
    private func previewed() -> Bool {
        // Return whether what we are seeing on the screen is the same as is in the toolbar
        return src == previewedSrc && alt == previewedAlt && scale == previewedScale
    }
    
    private func insertOrModify(handler: (()->Void)? = nil) {
        guard !previewed() else {
            handler?()
            return
        }
        if previewedSrc.isEmpty && !src.isEmpty {
            selectedWebView?.insertImage(src: argSrc, alt: argAlt) {
                previewedSrc = src
                previewedAlt = alt
                previewedScale = scale
                handler?()
            }
        } else {
            selectedWebView?.modifyImage(src: argSrc, alt: argAlt, scale: argScale) {
                previewedSrc = src
                previewedAlt = alt
                previewedScale = scale
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
    
    private func save() {
        // Save src, alt, scale if they haven't been previewed, and then close
        saving = true
        insertOrModify()
    }
    
    private func cancel() {
        // Restore src, alt, and scale to their initial values, put things back the way they were, and then close
        saving = true
        src = initialSrc ?? ""
        alt = initialAlt ?? ""
        scale = initialScale ?? 100
        insertOrModify()
    }
    
}

struct ImageToolbar_Previews: PreviewProvider {
    
    static var previews: some View {
        // src: "https://polyominoes.files.wordpress.com/2019/10/logo-1024.png", alt: "Polyominoes logo", scale: 100
        ImageToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}
