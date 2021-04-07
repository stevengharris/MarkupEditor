//
//  LabeledTextField.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/5/21.
//

import SwiftUI

struct ToolbarTextField: View {
    var label: String!
    var placeholder: String!
    @Binding var text: String
    var commitHandler: (()->Void)? = nil
    var isEditingHandler: ((Bool)->Void)? = nil
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .light))
            TextField(
                placeholder,
                text: $text,
                onEditingChanged: isEditingHandler ?? { _ in },
                onCommit: commitHandler ?? { }
            )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .background(Color(UIColor.systemGray6))
        }
    }
}

struct ToolbarTextField_Previews: PreviewProvider {
    static var previews: some View {
        ToolbarTextField(text: .constant("This is a preview"))
    }
}
