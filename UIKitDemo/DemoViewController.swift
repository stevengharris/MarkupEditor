//
//  DemoViewController.swift
//  UIKitDemo
//
//  Created by Steven Harris on 3/9/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import UIKit
import SwiftUI
import MarkupEditor
import Combine

/// The main view for the UIKitDemo.
///
/// Displays the MarkupEditorUIView containing demo.html and a TextView to display the raw HTML that can be toggled
/// on and off from the FileToolbar. By default, the MarkupEditorUIView shows the MarkupToolbarUIView at the top.
///
/// Acts as the MarkupDelegate to interact with editing operations as needed, and as the FileToolbarDelegate to interact
/// with the FileToolbar.
class DemoViewController: UIViewController {
    var stack: UIStackView!
    var webView: MarkupWKWebView!
    /// To see the raw HTML
    private var rawTextView: UITextView!
    private var bottomStack: UIStackView!
    private var bottomStackHeightConstraint: NSLayoutConstraint!
    /// Which MarkupWKWebView we have selected and which the MarkupToolbar acts on
    var selectedWebView: MarkupWKWebView? { MarkupEditor.selectedWebView }
    /// Toggle whether the file selector should be shown to select a local image
    var selectImageCancellable: AnyCancellable?
    // Note that we specify resoucesUrl when instantiating MarkupEditorUIView so that we can demonstrate
    // loading of local resources in the edited document. That resource, a png, is packaged along
    // with the rest of the demo app resources, so we get more than we wanted from resourcesUrl,
    // but that's okay for demo. Normally, you would want to put resources in a subdirectory of
    // where your html file comes from, or in a directory that holds both the html file and all
    // of its resources.
    private let resourcesUrl: URL? = URL(string: Bundle.main.resourceURL!.path)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializePickers()
        MarkupEditor.leftToolbar = AnyView(FileToolbar(fileToolbarDelegate: self))
        initializeStackView()
    }
    
    func initializePickers() {
        selectImageCancellable = MarkupEditor.selectImage.$value.sink { [weak self] value in
            if value {
                let controller =  UIDocumentPickerViewController(forOpeningContentTypes: [.image])
                controller.allowsMultipleSelection = false
                controller.delegate = self
                self?.present(controller, animated: true)
            }
        }
    }
    
    func divider(in parent: UIView) -> UIView {
        let parentView = parent
        let divider = UIView()
        parentView.addSubview(divider)
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.heightAnchor.constraint(equalToConstant: 1),
            divider.leftAnchor.constraint(equalTo: parentView.leftAnchor),
            divider.rightAnchor.constraint(equalTo: parentView.rightAnchor),
        ])
        divider.backgroundColor = UIColor.systemGray5
        return divider
    }
    
    /// Set up the stack that occupies the entire view. The stack contains the MarkupWKWebView and the rawTextView.
    ///
    /// The rawTextView height toggles as the raw text is shown.
    func initializeStackView() {
        // Create the stack
        stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .fill
        stack.frame = view.frame
        stack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(stack)
        // Create the webView and overlay the subToolbar
        let markupEditorView = MarkupEditorUIView(markupDelegate: self, html: demoHtml(), resourcesUrl: resourcesUrl, id: "Document")
        stack.addArrangedSubview(markupEditorView)
        bottomStack = UIStackView()
        bottomStack.isHidden = true
        bottomStack.axis = .vertical
        bottomStack.spacing = 8
        bottomStack.addArrangedSubview(divider(in: stack))
        let label = UILabel()
        label.text = "Document HTML"
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemGray5
        bottomStack.addArrangedSubview(label)
        rawTextView = UITextView()
        rawTextView.isEditable = false
        rawTextView.contentInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        bottomStack.addArrangedSubview(rawTextView)
        stack.addArrangedSubview(bottomStack)
        bottomStackHeightConstraint = NSLayoutConstraint(item: bottomStack!, attribute: .height, relatedBy: .equal, toItem: markupEditorView, attribute: .height, multiplier: 1, constant: 1)
    }
    
    private func setRawText(_ handler: (()->Void)? = nil) {
        selectedWebView?.getHtml { html in
            self.rawTextView.attributedText = self.attributedString(from: html ?? "")
            handler?()
        }
    }
    
    private func attributedString(from string: String) -> NSAttributedString {
        // Return a monospaced attributed string for the rawText that is expecting to be a good dark/light mode citizen
        var attributes = [NSAttributedString.Key: AnyObject]()
        attributes[.foregroundColor] = UIColor.label
        attributes[.font] = UIFont.monospacedSystemFont(ofSize: StyleContext.P.fontSize, weight: .regular)
        return NSAttributedString(string: string, attributes: attributes)
    }
    
    private func openExistingDocument(url: URL) {
        do {
            let html = try String(contentsOf: url, encoding: .utf8)
            selectedWebView?.setHtml(html) {
                self.setRawText()
            }
        } catch let error {
            print("Error loading html: \(error.localizedDescription)")
        }
    }
    
    private func imageSelected(url: URL) {
        guard let view = selectedWebView else { return }
        markupImageToAdd(view, url: url)
    }
    
    private func demoHtml() -> String {
        guard let demoUrl = Bundle.main.url(forResource: "demo", withExtension: "html") else { return "" }
        return (try? String(contentsOf: demoUrl)) ?? ""
    }

}

extension DemoViewController: MarkupDelegate {
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        MarkupEditor.observedWebView.selectedWebView = view
        setRawText(handler)
    }
    
    func markupInput(_ view: MarkupWKWebView) {
        // This is way too heavyweight, but it suits the purposes of the demo
        setRawText()
    }
    
    func markupImageAdded(url: URL) {
        print("Image added from \(url.path)")
    }
    
    /// Override the default behavior for when the MarkupEditor encounters an error.
    ///
    /// In the event of a MUError.Alert, play an alert sound.
    func markupError(code: String, message: String, info: String?, alert: Bool) {
        print("Error \(code): \(message)")
        if let info = info { print(" \(info)") }
    }
    
}

extension DemoViewController: FileToolbarDelegate {
    
    func newDocument(handler: ((URL?)->Void)? = nil) {
        selectedWebView?.emptyDocument() {
            self.setRawText()
        }
    }
    
    func existingDocument(handler: ((URL?)->Void)? = nil) {
        let controller =  UIDocumentPickerViewController(forOpeningContentTypes: [.html])
        controller.allowsMultipleSelection = false
        controller.delegate = self
        present(controller, animated: true)
    }
    
    func rawDocument() {
        let willBeHidden = !bottomStack.isHidden
        bottomStackHeightConstraint.isActive = !willBeHidden
        bottomStack.isHidden = willBeHidden
    }
    
}

extension DemoViewController: UIDocumentPickerDelegate {
    
    /// Handle the two cases for the document picker: selecting a local image and opening an existing html document.
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if (MarkupEditor.selectImage.value) {
            MarkupEditor.selectImage.value = false
            imageSelected(url: url)
        } else {
            openExistingDocument(url: url)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        MarkupEditor.selectImage.value = false
        controller.dismiss(animated: true, completion: nil)
    }
    
}
