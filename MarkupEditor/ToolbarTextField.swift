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
    @State var previousText: String     // Hack to deal with tab navigation
    @State var takeFocusOn: String?     // Set at init time to indicate when to focus
    @Binding var focusIsOn: String      // Set externally to indicate where focus is
    @available (iOS 15.0, macCatalyst 15.0, *)
    @FocusState var fieldIsFocused: Bool
    
    public var body: some View {
        switch toolbarPreference.style {
        case .labeled:
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .light))
                if #available(iOS 15.0, macCatalyst 15.0, *) {
                    TextField(
                        label,
                        text: $text,
                        prompt: Text(placeholder))
                    .onChange(of: text) { value in
                        // I can't find any way to use tab-based navigation, so this hack
                        // of checking for tab input is the best I could figure out.
                        // Why oh why, SwiftUI!?
                        if value.last == "\t" {
                            let noTabText = String(text.dropLast());
                            if noTabText.count == 0 {
                                $text.wrappedValue = previousText
                            } else {
                                $text.wrappedValue = noTabText
                            }
                            commitHandler?()
                        } else {
                            previousText = text
                        }
                    }
                    .onSubmit { commitHandler?() }
                    .onAppear { fieldIsFocused = focusIsOn == takeFocusOn }
                    .focused($fieldIsFocused)
                    .onChange(of: focusIsOn) { focus in fieldIsFocused = focus == takeFocusOn }
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
            if #available(iOS 15.0, macCatalyst 15.0, *) {
                TextField(
                    label,
                    text: $text,
                    prompt: Text(placeholder))
                .onChange(of: text) { value in
                    // I can't find any way to use tab-based navigation, so this hack
                    // of checking for tab input is the best I could figure out.
                    // Why oh why, SwiftUI!?
                    if value.last == "\t" {
                        let noTabText = String(text.dropLast());
                        if noTabText.count == 0 {
                            $text.wrappedValue = previousText
                        } else {
                            $text.wrappedValue = noTabText
                        }
                        commitHandler?()
                    } else {
                        previousText = text
                    }
                }
                .onSubmit { commitHandler?() }
                .onAppear { fieldIsFocused = focusIsOn == takeFocusOn }
                .focused($fieldIsFocused)
                .onChange(of: focusIsOn) { focus in fieldIsFocused = focus == takeFocusOn }
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
    
    public init(label: String, placeholder: String, text: Binding<String>, commitHandler: (()->Void)? = nil, validationHandler: (()->Bool)? = nil, takeFocusOn: String? = nil, focusIsOn: Binding<String> = .constant("")) {
        self.label = label
        _text = text
        previousText = text.wrappedValue
        self.placeholder = placeholder
        self.commitHandler = commitHandler
        self.validationHandler = validationHandler
        _takeFocusOn = State(initialValue: takeFocusOn)
        _focusIsOn = focusIsOn
    }
    
}
