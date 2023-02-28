//
//  ForcePopoverModifier.swift
//  MarkupEditor
//
//  Modeled after https://pspdfkit.com/blog/2022/presenting-popovers-on-iphone-with-swiftui/
//  Modified by Steven G. Harris
//

import SwiftUI

struct ForcePopoverModifier<PopoverContent>: ViewModifier where PopoverContent: View {
    
    let isPresented: Binding<Bool>
    let content: () -> PopoverContent
    @State private var anchorView = UIView()
    @State private var presentedVC: UIViewController?
    
    func body(content: Content) -> some View {
        if isPresented.wrappedValue {
            presentPopover()
        } else {
            dismissPopover()
        }
        return content
            .background(InternalAnchorView(uiView: anchorView))
    }
    
    init(isPresented: Binding<Bool>, content: @escaping ()->PopoverContent) {
        self.isPresented = isPresented
        self.content = content
    }
    
    private func presentPopover() {
        let hostingController = PopoverHostingController(rootView: content(), isPresented: isPresented)
        hostingController.modalPresentationStyle = .popover
        guard let popover = hostingController.popoverPresentationController else { return }
        popover.sourceView = anchorView
        popover.sourceRect = anchorView.bounds
        popover.delegate = hostingController
        guard let sourceVC = anchorView.closestVC() else { return }
        sourceVC.present(hostingController, animated: true) {
            // When the popover is presented from the keyboard inputAccessory,
            // the sourceVC.presentedViewController will be nil. The actual presentingViewController
            // is a UIInputWindowController, and attempting to walk up the chain from sourceVC using
            // nearestVC to relocate it for dismiss later will return the wrong ViewController.
            // For this reason, retain the presentedVC directly here, which won't be the same as
            // sourceVC in the keyboard inputAccessory case.
            presentedVC = hostingController.presentingViewController?.presentedViewController
        }
    }
    
    private func dismissPopover() {
        // It's "normal" for dismissPopover to be called when the popover is not presented
        // (i.e., when presentedVC is nil), such as when the TableToolbar is presented but
        // before the user presents the TableSizer.
        guard let presentedVC else { return }
        presentedVC.dismiss(animated: true) {
            self.presentedVC = nil
        }
    }
    
    private struct InternalAnchorView: UIViewRepresentable {
        typealias UIViewType = UIView
        let uiView: UIView
        
        func makeUIView(context: Self.Context) -> Self.UIViewType {
            uiView
        }
        
        func updateUIView(_ uiView: Self.UIViewType, context: Self.Context) { }
    }
}
