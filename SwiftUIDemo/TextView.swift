//
//  TextView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 4/9/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

struct TextView: UIViewRepresentable {
    @Binding var text: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        UITextView()
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.backgroundColor = UIColor.systemBackground
        uiView.attributedText = text
        uiView.spellCheckingType = .no
        uiView.autocorrectionType = .no
    }
}
