//
//  SwiftUIView.swift
//  
//
//  Created by Steven Harris on 3/24/21.
//

import SwiftUI

public struct MarkupImageToolbar: View {
    @Binding var showImageToolbar: Bool
    @Binding private var selectedWebView: MarkupWKWebView?
    @ObservedObject private var selectionState: SelectionState
    private var markupUIDelegate: MarkupUIDelegate?
    private var initialSrc: String?
    private var initialAlt: String?
    private var initialScale: Int?
    private let scaleStep: Int = 5
    // The src, alt, and scale values are the state for the toolbar
    @State private var src: String?
    @State private var alt: String?
    @State private var scale: Int?
    // The "arg" equivalent is for scale passed to create/modifyImage
    private var argScale: Int? { actualScale == 100 ? nil : scale }
    // Since scale=nil means 100%, actualScale always gives us an Int when we need it
    private var actualScale: Int { scale ?? 100 }
    @State private var saving: Bool = false
    @State private var previewed: Bool = false
    @State private var endedEditing: Bool = false
    
    public var body: some View {
        HStack {
            VStack(spacing: 2) {
                Text("Image URL")
                    .font(.system(size: 10, weight: .light))
                MarkupTextField(text: $src, endedEditing: $endedEditing, placeholder: "Enter URL", isFirstResponder: true)
                    .onChange(of: endedEditing, perform: { value in if value { preview() }})
                    .background(Color(UIColor.systemGray6))
            }
            VStack(spacing: 2) {
                Text("Description")
                    .font(.system(size: 10, weight: .light))
                MarkupTextField(text: $alt, endedEditing: $endedEditing, placeholder: "Enter Description")
                    .onChange(of: endedEditing, perform: { value in if value { preview() }})
                    .background(Color(UIColor.systemGray6))
            }
            Divider()
            VStack(spacing: 2) {
                Text("Scale")
                    .font(.system(size: 10, weight: .light))
                Stepper(onIncrement: incrementScale, onDecrement: decrementScale) { Text("\(actualScale)%").frame(width: 50) }
            }
            .scaledToFit()
            Divider()
            VStack(spacing: 2) {
                Spacer()
                HStack(alignment: .center) {
                    Button(action: { self.save() }) { Text("Save").frame(width: 80) }
                    Button(action: { self.cancel() }) { Text("Cancel").frame(width: 80) }
                }
                .buttonStyle(ToolbarTextButtonStyle())
            }
            Spacer()
        }
        .onChange(of: selectionState.src, perform: { value in
            src = selectionState.src
            alt = selectionState.alt
            scale = selectionState.scale
        })
        .fixedSize(horizontal: false, vertical: true)
        .frame(idealHeight: 50, maxHeight: 50)
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, showImageToolbar: Binding<Bool>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        _showImageToolbar = showImageToolbar
        initialSrc = selectionState.src
        initialAlt = selectionState.alt
        initialScale = selectionState.scale
        _src = State(initialValue: initialSrc)
        _alt = State(initialValue: initialAlt)
        _scale = State(initialValue: initialScale)
    }
    
    private func incrementScale() {
        // We need to reset scale and then set it back to avoid this bug:
        // https://stackoverflow.com/questions/58960251/strange-behavior-of-stepper-in-swiftui
        scale = actualScale + scaleStep
        if actualScale > 100 {
            scale = 100
        } else {
            guard let view = selectedWebView, src != nil else {
                scale = actualScale - scaleStep
                return
            }
            view.modifyImage(src: src, alt: alt, scale: scale)
        }
    }
    
    private func decrementScale() {
        // We need to reset scale and then set it back to avoid this bug:
        // https://stackoverflow.com/questions/58960251/strange-behavior-of-stepper-in-swiftui
        scale = actualScale - scaleStep
        if actualScale < scaleStep {
            scale = scaleStep
        } else {
            guard let view = selectedWebView, src != nil else {
                scale = actualScale + scaleStep
                return
            }
            view.modifyImage(src: src, alt: alt, scale: scale)
        }
    }
    
    private func preview() {
        // The onChange event can fire and cause preview during the save operation.
        // So, if we are saving, then never preview.
        if saving { return }
        selectedWebView?.prepareInsert { error in
            if error == nil {
                previewed = true
                if !previewed {
                    selectedWebView?.insertImage(src: src, alt: alt)
                } else {
                    selectedWebView?.modifyImage(src: src, alt: alt, scale: argScale)
                }
            }
        }
    }
    
    private func save() {
        saving = true
        if !previewed {
            selectedWebView?.prepareInsert { error in
                if error == nil {
                    if initialSrc == nil {
                        selectedWebView?.insertImage(src: src, alt: alt)
                    } else {
                        selectedWebView?.modifyImage(src: src, alt: alt, scale: argScale)
                    }
                    withAnimation { showImageToolbar.toggle() }
                } else {
                    // If we don't close the toolbar because of an error, then reset saving
                    saving = false
                }
            }
        }
    }
    
    private func cancel() {
        selectedWebView?.modifyImage(src: initialSrc, alt: initialAlt, scale: initialScale)
        withAnimation { showImageToolbar.toggle() }
        
    }
    
}

struct MarkupImageToolbar_Previews: PreviewProvider {
    
    static var previews: some View {
        // src: "https://polyominoes.files.wordpress.com/2019/10/logo-1024.png", alt: "Polyominoes logo", scale: 100
        MarkupImageToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil), showImageToolbar: .constant(true))
    }
}
