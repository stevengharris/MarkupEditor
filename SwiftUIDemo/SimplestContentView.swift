//
//  SimplestContentView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 8/20/22.
//

import SwiftUI
import MarkupEditor

struct SimplestContentView: View {
    
    @State private var demoHtml: String = "<h1>Hello World</h1>"
    
    var body: some View {
        MarkupEditorView(html: $demoHtml)
    }
    
}
