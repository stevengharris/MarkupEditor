//
//  ToolbarTextField.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/5/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

public struct ToolbarTextField: View {
    let label: String!
    let placeholder: String!
    @Binding var text: String
    let commitHandler: (()->Void)?
    let isEditingHandler: ((Bool)->Void)?
    let validationHandler: (()->Bool)?
    
    public var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .light))
            TextField(
                placeholder,
                text: $text,
                onEditingChanged: isEditingHandler ?? { _ in },
                onCommit: commitHandler ?? { }
            )
            .textFieldStyle(PlainTextFieldStyle())
            .padding([.leading, .trailing], 8)
            .frame(height: 30)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(UIColor.systemGray5)))
            .foregroundColor((validationHandler?() ?? true) ? Color(UIColor.label) : Color.red)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .background(Color(UIColor.systemBackground))
        }
    }
    
    public init(label: String, placeholder: String, text: Binding<String>, commitHandler: (()->Void)? = nil, isEditingHandler: ((Bool)->Void)? = nil, validationHandler: (()->Bool)? = nil) {
        self.label = label
        _text = text
        self.placeholder = placeholder
        self.commitHandler = commitHandler
        self.isEditingHandler = isEditingHandler
        self.validationHandler = validationHandler
    }
    
}
