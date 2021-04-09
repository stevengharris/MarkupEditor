//
//  LabeledTextField.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/5/21.
//

import SwiftUI

public struct ToolbarTextField: View {
    var label: String!
    var placeholder: String!
    @Binding var text: String
    var commitHandler: (()->Void)? = nil
    var isEditingHandler: ((Bool)->Void)? = nil
    var validationHandler: (()->Bool)? = nil
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
}

struct ToolbarTextField_Previews: PreviewProvider {
    static var previews: some View {
        ToolbarTextField(text: .constant("This is a preview"))
    }
}
