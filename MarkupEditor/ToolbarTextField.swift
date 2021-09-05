//
//  ToolbarTextField.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/5/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The TextField used in the ImageToolbar and LinkToolbar.
public struct ToolbarTextField: View {
    @EnvironmentObject var toolbarPreference: ToolbarPreference
    private var height: CGFloat { toolbarPreference.style == .compact ? 24 : 30 }
    let label: String!
    let placeholder: String!
    @Binding var text: String
    let commitHandler: (()->Void)?
    let isEditingHandler: ((Bool)->Void)?
    let validationHandler: (()->Bool)?
    
    public var body: some View {
        switch toolbarPreference.style {
        case .labeled:
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .light))
                TextField(
                    placeholder,
                    text: $text,
                    onEditingChanged: isEditingHandler ?? { _ in },
                    onCommit: commitHandler ?? { }
                )
                .frame(height: height)
                .opacity(1)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color(UIColor.systemGray5))
                )
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(UIColor.systemBackground))
                )
                .foregroundColor((validationHandler?() ?? true) ? Color(UIColor.label) : Color.red)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            }
        case .compact:
            TextField(
                placeholder,
                text: $text,
                onEditingChanged: isEditingHandler ?? { _ in },
                onCommit: commitHandler ?? { }
            )
            .frame(height: height)
            .opacity(1)
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.horizontal, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(UIColor.systemGray5))
            )
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(UIColor.systemBackground))
            )
            .foregroundColor((validationHandler?() ?? true) ? Color(UIColor.label) : Color.red)
            .autocapitalization(.none)
            .disableAutocorrection(true)
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
