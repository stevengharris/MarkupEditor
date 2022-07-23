//
//  ForcePopoverModifier.swift
//  MarkupEditor
//
//  Modeled after https://pspdfkit.com/blog/2022/presenting-popovers-on-iphone-with-swiftui/
//  Modified by Steven G. Harris
//

import SwiftUI

struct ForcePopoverModifier<PopoverContent>: ViewModifier where PopoverContent: View {
    
    @Binding var isPresented: Bool
    let contentBlock: () -> PopoverContent
    @State private var wasPresented = false
    @State var anchorView = UIView()
    
    func body(content: Content) -> some View {
        if isPresented {
            presentPopover()
        } else {
            dismissPopover()
        }
        return content
            .background(InternalAnchorView(uiView: anchorView))
    }
    
    private func presentPopover() {
        let contentController = PopoverHostingController(rootView: contentBlock(), isPresented: $isPresented)
        contentController.modalPresentationStyle = .popover
        guard let popover = contentController.popoverPresentationController else { return }
        popover.sourceView = anchorView
        popover.sourceRect = anchorView.bounds
        popover.delegate = contentController
        closestVC(to: anchorView)?.present(contentController, animated: true)
    }
    
    private func dismissPopover() {
        // It's normal for there to be no sourceVC when things start
        guard let sourceVC = closestVC(to: anchorView) else { return }
        if let presentedVC = sourceVC.presentedViewController {
            presentedVC.dismiss(animated: true)
        }
    }
    
    private func closestVC(to uiView: UIView) -> UIViewController? {
        var responder: UIResponder? = uiView
        while responder != nil {
            if let vc = responder as? UIViewController {
                return vc
            }
            responder = responder?.next
        }
        return nil
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
