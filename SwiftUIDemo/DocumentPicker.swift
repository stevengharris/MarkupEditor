//
//  DocumentPicker.swift
//  Modeled from https://www.objc.io/blog/2020/04/21/swiftui-alert-with-textfield/
//  SwiftUIDemo
//
//  Created by Steven Harris on 4/13/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

#if !os(macOS)

import SwiftUI
import UniformTypeIdentifiers

extension View {
    
    /// Present a UIDocumentVIewController, toggling isPresented when done
    public func pick(isPresented: Binding<Bool>, documentTypes: [UTType], onPicked: ((URL)->Void)?, onCancel: (()->Void)?) -> some View {
        DocumentPicker(isPresented: isPresented, content: self, documentTypes: documentTypes, onPicked: onPicked, onCancel: onCancel)
    }
    
}

/// A SwiftUI presentation of a UIDocumentViewController for a single pick of a document of type given in documentTypes
/// Invoke using .pick on the presenting View
struct DocumentPicker<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content: Content
    var documentTypes: [UTType]
    var onPicked: ((URL) -> Void)?
    var onCancel: (() -> Void)?
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPicker>) -> UIHostingController<Content> {
        UIHostingController(rootView: content)
    }
    
    /// Coordinator for DocumentPicker, which acts as the UIDocumentPickerDelegate
    /// The UIDocumentPickerDelegate needs to be an NSObject, so cannot be handled by the DocumentPicker itself
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var uiPicker: UIDocumentPickerViewController?
        var onPicked: ((URL) -> Void)?
        var onCancel: (() -> Void)?
        
        init(_ picker: UIDocumentPickerViewController? = nil) {
            super.init()
            uiPicker = picker
            uiPicker?.delegate = self
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            onPicked?(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel?()
        }
        
    }
    
    /// Return a Coordinator that toggles isPresented before executing onPicked or onCancel
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        let onPickedToggle: ((URL)->Void) = { url in
            isPresented.toggle()
            onPicked?(url)
        }
        coordinator.onPicked = onPickedToggle
        let onCancelToggle: (()->Void) = {
            isPresented.toggle()
            onCancel?()
        }
        coordinator.onCancel = onCancelToggle
        return coordinator
    }
    
    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: UIViewControllerRepresentableContext<DocumentPicker>) {
        uiViewController.rootView = content
        if isPresented && uiViewController.presentedViewController == nil {
            let controller =  UIDocumentPickerViewController(forOpeningContentTypes: documentTypes)
            controller.allowsMultipleSelection = false
            controller.delegate = context.coordinator
            context.coordinator.uiPicker = controller
            uiViewController.present(controller, animated: true)
        }
        if !isPresented && uiViewController.presentedViewController == context.coordinator.uiPicker {
            uiViewController.dismiss(animated: true)
        }
    }
    
}

#endif

