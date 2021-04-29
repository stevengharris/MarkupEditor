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
        }
    }
}

struct LabeledToolbar_Previews: PreviewProvider {
    static var previews: some View {
        LabeledToolbar(label: Text("Test Label")) {
            ToolbarImageButton(image: Image(systemName: "square.and.arrow.up.fill"), action: { print("up")})
            ToolbarImageButton(image: Image(systemName: "square.and.arrow.down.fill"), action: { print("down")})
        }
    }
}
