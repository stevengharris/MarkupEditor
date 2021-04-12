//
//  TextView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 4/9/21.
//

import SwiftUI

struct TextView: UIViewRepresentable {
    @Binding var text: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        UITextView()
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = text
    }
}
