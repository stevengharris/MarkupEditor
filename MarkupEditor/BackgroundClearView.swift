//
//  BackgroundClearView.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/30/22.
//  Modeled on https://stackoverflow.com/a/63745596
//

import SwiftUI

struct BackgroundClearView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
