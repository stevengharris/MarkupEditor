//
//  MarkupAlertController.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/12/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//
//  Adapted from https://gist.github.com/chriseidhof
//  Created by Chris Eidhof on 20.04.20.
//  Copyright © 2020 objc.io. All rights reserved.
//

import SwiftUI
import UIKit

/// The SwiftUI representation of a UIAlertController containing a single text field and an accept and cancel button.
///
/// To use, create the TextAlert with the proper contents and then use the `alert(isPresented:_:) -> some View` or
/// `alert(item:_:) -> some View` function of the View extension
struct MarkupAlertController<Content: View>: UIViewControllerRepresentable {
    var isPresented: Bool { item != nil }
    @Binding var item: MarkupAlert?
    let alert: TextAlert
    let content: Content
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<MarkupAlertController>) -> UIHostingController<Content> {
        UIHostingController(rootView: content)
    }
    
    final class Coordinator {
        var alertController: UIAlertController?
        
        init(_ controller: UIAlertController? = nil) {
            self.alertController = controller
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func updateUIViewController(_ uiViewController: UIHostingController<Content>, context: UIViewControllerRepresentableContext<MarkupAlertController>) {
        uiViewController.rootView = content
        if isPresented && uiViewController.presentedViewController == nil {
            var alert = self.alert
            alert.action = {
                self.item = nil
                self.alert.action($0, $1)
            }
            context.coordinator.alertController = UIAlertController(alert: alert)
            uiViewController.present(context.coordinator.alertController!, animated: true)
        }
        if !isPresented && uiViewController.presentedViewController == context.coordinator.alertController {
            uiViewController.dismiss(animated: true)
        }
    }
    
}

/// Holds the contents + action that will be set up in the UIAlertController that is available in SwiftUI as a MarkupAlertController
public struct TextAlert {
    public var title: String
    public var action: (String?, String?)->()
    public var placeholder1: String?
    public var placeholder2: String?
    public var message: String?
    public var text1: String?
    public var text2: String?
    public var accept: String
    public var cancel: String
    
    public init(
        title: String,
        action: @escaping (String?, String?)->(),
        placeholder1: String? = nil,
        placeholder2: String? = nil,
        message: String? = nil,
        text1: String? = nil,
        text2: String? = nil,
        accept: String = "OK",
        cancel: String = "Cancel") {
        self.title = title
        self.action = action
        self.placeholder1 = placeholder1
        self.placeholder2 = placeholder2
        self.text1 = text1
        self.text2 = text2
        self.accept = accept
        self.cancel = cancel
    }
    
}

extension UIAlertController {
    
    /// Create a UIAlertController whose contents is specified in a TextAlert
    public convenience init(alert: TextAlert) {
        self.init(title: alert.title, message: alert.message, preferredStyle: .alert)
        // If there is no text1 or placeholder1, then don't add any text fields
        var textFieldCount = 0
        if alert.text1 != nil || alert.placeholder1 != nil {
            textFieldCount += 1
            addTextField { textField in
                textField.text = alert.text1
                textField.placeholder = alert.placeholder1
            }
            // THe 2nd text field is optional
            if alert.text2 != nil || alert.placeholder2 != nil {
                textFieldCount += 1
                addTextField { textField in
                    textField.text = alert.text2
                    textField.placeholder = alert.placeholder2
                }
            }
        }
        let acceptAction = UIAlertAction(title: alert.accept, style: .destructive) { _ in
            switch textFieldCount {
            case 1:
                alert.action(self.textFields?[0].text, nil)
            case 2:
                alert.action(self.textFields?[0].text, self.textFields?[1].text)
            default:
                alert.action(nil, nil)
            }
        }
        let cancelAction = UIAlertAction(title: alert.cancel, style: .default) { _ in
            alert.action(nil, nil)
        }
        addAction(acceptAction)
        addAction(cancelAction)
        preferredAction = acceptAction
    }
    
}

extension View {
    
    /// The MarkupAlertController equivalent to Alert function `alert(isPresented:content:)`
    //public func alert(isPresented: Binding<Bool>, _ alert: TextAlert) -> some View {
    //    MarkupAlertController(isPresented: isPresented, alert: alert, content: self)
    //}
    
    /// The MarkupAlertController equivalent to Alert function `alert(item:content:)`
    public func alert(item: Binding<MarkupAlert?>, _ alert: TextAlert) -> some View {
        return MarkupAlertController(item: item, alert: alert, content: self)
    }
    
}

struct AlertContentView: View, MarkupUIDelegate {
    @State var markupAlert: MarkupAlert?
    var body: some View {
        VStack {
            Button("Show Link Alert") {
                self.markupAlert = MarkupAlert(type: .link)
            }
            Button("Show Image Alert") {
                self.markupAlert = MarkupAlert(type: .image)
            }
        }
        .alert(item: $markupAlert, markupTextAlert(nil, type: markupAlert?.type ?? .unknown, selectionState: SelectionState()))
    }
}

struct AlertContentView_Previews: PreviewProvider {
    static var previews: some View {
        AlertContentView()
    }
}
