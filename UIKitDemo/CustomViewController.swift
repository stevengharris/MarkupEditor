//
//  CustomViewController.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/13/24.
//

import UIKit
import SwiftUI
import MarkupEditor
import Combine

/// Identical to the DemoViewController, except also demonstrating the use of custom.js and custom.css
/// to customize style and add a user script that returns the word count of the document.
class CustomViewController: UIViewController {
    var stack: UIStackView!
    var webView: MarkupWKWebView!
    /// To see the raw HTML
    private var rawTextView: UITextView!
    private var bottomStack: UIStackView!
    private var wordCountLabel: UILabel!
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
    /// The `markupConfiguration` holds onto the userCSSFile and userScriptFile we set in viewDidLoad.
    private let markupConfiguration = MarkupWKWebViewConfiguration()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Identify the the css and js that will be loaded after markup.html is fully loaded.
        // For demo purposes, both files are included in SharedDemo. See markupLoaded below
        // where the classes are assigned using a call to `assignClasses` in the MarkupWKWebView.
        markupConfiguration.userCssFile = "custom.css"
        markupConfiguration.userScriptFile = "custom.js"
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
        wordCountLabel = UILabel()
        wordCountLabel.textAlignment = .center
        stack.addSubview(wordCountLabel)
        wordCountLabel.translatesAutoresizingMaskIntoConstraints = false
        // Really UIKit, this is what I need to do to get safeAreaInsets in a view controller!?
        let window = UIApplication.shared.connectedScenes.compactMap({($0 as? UIWindowScene)?.keyWindow}).last
        let topPadding = window?.safeAreaInsets.top ?? 30
        NSLayoutConstraint.activate([
            wordCountLabel.topAnchor.constraint(equalTo: stack.topAnchor, constant: topPadding + 10),
            wordCountLabel.heightAnchor.constraint(equalToConstant: 40),
            wordCountLabel.leftAnchor.constraint(equalTo: stack.leftAnchor),
            wordCountLabel.rightAnchor.constraint(equalTo: stack.rightAnchor),
        ])
        stack.addArrangedSubview(wordCountLabel)
        // Create the webView
        let markupEditorView = MarkupEditorUIView(markupDelegate: self, configuration: markupConfiguration, html: demoHtml(), resourcesUrl: resourcesUrl, id: "Document")
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
            self.selectedWebView?.wordcount { count in
                self.wordCountLabel.text = "Word count: \(count ?? 0)"
            }
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

extension CustomViewController: MarkupDelegate {
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        // Now that the code in markup.js and custom.js has been loaded, and the markup.css and custom.css
        // have been set, we can invoke assigClasses to set the classes that custom.css styles.
        MarkupEditor.selectedWebView = view
        setRawText(handler)
    }
    
    func markupInput(_ view: MarkupWKWebView) {
        // This is way too heavyweight, but it suits the purposes of the demo
        setRawText()
    }
    
    func markupImageAdded(url: URL) {
        print("Image added from \(url.path)")
    }
    
}

extension CustomViewController: FileToolbarDelegate {
    
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

extension CustomViewController: UIDocumentPickerDelegate {
    
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
