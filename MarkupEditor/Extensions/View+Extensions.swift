//
//  View+Modifiers.swift
//  MarkupEditor
//
//  Modeled after https://pspdfkit.com/blog/2022/presenting-popovers-on-iphone-with-swiftui/
//

import SwiftUI

#if os(iOS) && !targetEnvironment(macCatalyst)
extension View {

    @MainActor public func forcePopover<Content>(
        isPresented: Binding<Bool>,
        at rect: CGRect? = nil,
        arrowEdge: Edge? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View where Content : View {
        modifier(
            ForcePopoverModifier(
                isPresented: isPresented,
                at: rect,
                arrowEdge: arrowEdge,
                content: content)
        )
    }

}
#else
extension View {

    @MainActor public func forcePopover<Content>(
        isPresented: Binding<Bool>,
        at rect: CGRect? = nil,
        arrowEdge: Edge? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View where Content : View {
        // On macCatalyst and macOS, the standard .popover works properly
        guard let rect else {
            // If we don't have rect, just use all defaults
            return popover(
                isPresented: isPresented,
                content: content
            )
        }
        guard let arrowEdge else {
            // If we don't have arrowEdge, just use the rect
            return popover(
                isPresented: isPresented,
                attachmentAnchor: .rect(.rect(rect)),
                content: content
            )
        }
        return popover(
            // We have the whole shebang, so use them all
            isPresented: isPresented,
            attachmentAnchor: .rect(.rect(rect)),
            arrowEdge: arrowEdge,
            content: content
        )
    }

}
#endif
