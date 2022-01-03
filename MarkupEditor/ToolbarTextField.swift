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
    let label: String!
    let placeholder: String!
    @Binding var text: String
    let commitHandler: (()->Void)?
    let validationHandler: (()->Bool)?
    let loseFocusHandler: (()->Void)?
    @available (macCatalyst 15.0, *)
    @FocusState var textIsFocused: Bool
    
    public var body: some View {
        switch toolbarPreference.style {
        case .labeled:
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .light))
                if #available(macCatalyst 15.0, *) {
                    TextField(
                        label,
                        text: $text,
                        prompt: Text(placeholder))
                        .onSubmit { commitHandler?() }
                        .onAppear { DispatchQueue.main.async { textIsFocused = true } }  // Doesn't work without the aync
                        .focused($textIsFocused)
                        .onChange(of: textIsFocused) { focused in if !focused { loseFocusHandler?() } }
                        .frame(height: toolbarPreference.buttonHeight())
                        .opacity(1)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor((validationHandler?() ?? true) ? Color(UIColor.label) : Color.red)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } else {
                    TextField(
                        placeholder,
                        text: $text,
                        onCommit: commitHandler ?? { })
                        .frame(height: toolbarPreference.buttonHeight())
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
        case .compact:
            if #available(macCatalyst 15.0, *) {
                TextField(
                    label,
                    text: $text,
                    prompt: Text(placeholder))
                    .onSubmit { commitHandler?() }
                    .onAppear { DispatchQueue.main.async { textIsFocused = true } }  // Doesn't work without the aync
                    .focused($textIsFocused)
                    .onChange(of: textIsFocused) { focused in if !focused { loseFocusHandler?() } }
                    .frame(height: toolbarPreference.buttonHeight())
                    .opacity(1)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .foregroundColor((validationHandler?() ?? true) ? Color(UIColor.label) : Color.red)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } else {
                TextField(
                    placeholder,
                    text: $text,
                    onCommit: commitHandler ?? {})
                    .frame(height: toolbarPreference.buttonHeight())
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
    }
    
    public init(label: String, placeholder: String, text: Binding<String>, commitHandler: (()->Void)? = nil, validationHandler: (()->Bool)? = nil, loseFocusHandler: (()->Void)? = nil) {
        self.label = label
        _text = text
        self.placeholder = placeholder
        self.commitHandler = commitHandler
        self.validationHandler = validationHandler
        self.loseFocusHandler = loseFocusHandler
    }
    
}
