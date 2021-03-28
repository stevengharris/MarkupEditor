//
//  MarkupTextField.swift
//  Thanks to https://stackoverflow.com/a/56508132/8968411
//  
//
//  Created by Steven Harris on 3/25/21.
//

import SwiftUI

struct MarkupTextField: UIViewRepresentable {

    class Coordinator: NSObject, UITextFieldDelegate {

        @Binding var text: String?
        @Binding var endedEditing: Bool
        var didBecomeFirstResponder = false

        init(text: Binding<String?>, endedEditing: Binding<Bool>) {
            _text = text
            _endedEditing = endedEditing
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            endedEditing = true
        }

    }

    @Binding var text: String?
    @Binding var endedEditing: Bool
    var placeholder: String?
    var isFirstResponder: Bool = false
    
    static func dismantleUIView(_ uiView: UITextField, coordinator: Coordinator) {
        uiView.resignFirstResponder()
    }

    func makeUIView(context: UIViewRepresentableContext<MarkupTextField>) -> UITextField {
        let textField = UITextField(frame: .zero)
        // The following is set so that the text sticks within the bounds of the UITextField
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // Pad the left so it doesn't look so crowded
        let leftView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 8, height: 0)))
        leftView.backgroundColor = textField.backgroundColor
        textField.leftView = leftView
        textField.leftViewMode = .always
        textField.autocorrectionType = .no
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        return textField
    }

    func makeCoordinator() -> MarkupTextField.Coordinator {
        return Coordinator(text: $text, endedEditing: $endedEditing)
    }

    func updateUIView(_ uiView: UITextField, context: UIViewRepresentableContext<MarkupTextField>) {
        uiView.text = text
        if isFirstResponder && !context.coordinator.didBecomeFirstResponder  {
            uiView.becomeFirstResponder()
            context.coordinator.didBecomeFirstResponder = true
        }
    }
    
}
