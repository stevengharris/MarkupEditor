//
//  LabeledToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/29/21.
//

import SwiftUI

public struct LabeledToolbar<Content: View>: View {
    let label: Text
    let content: Content
    
    public init(label: Text, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    public var body: some View {
        VStack(spacing: 2) {
            label
                .font(.system(size: 10, weight: .light))
            HStack(alignment: .bottom) {
                content
            }
            // The following fixes a problem with the individual buttons only being partially
            // tappable, while preserving the .onHover behavior.
            .gesture(TapGesture(), including: .subviews)
        }
    }
}

struct LabeledToolbar_Previews: PreviewProvider {
    static var previews: some View {
        LabeledToolbar(label: Text("Test Label")) {
            ToolbarImageButton(action: { print("up") }) { Image.forToolbar(systemName: "square.and.arrow.up.fill") }
            ToolbarImageButton(action: { print("down") }) { Image.forToolbar(systemName: "square.and.arrow.down.fill")}
        }
    }
}
