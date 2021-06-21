//
//  ViewController.swift
//  UIKitDemo
//
//  Created by Steven Harris on 3/9/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import UIKit
import SwiftUI
import MarkupEditor

class ViewController: UIViewController {
    @IBOutlet weak var stack: UIStackView!
    var toolbarHolder: UIView!
    var webView: MarkupWKWebView!
    /// The MarkupCoordinator deals with the interaction with the MarkupWKWebView
    private var coordinator: MarkupCoordinator!
    /// The MarkupToolbar is the SwiftUI component held in the toolbarHolder UIView
    private var toolbar: MarkupToolbar!
    private let toolbarHeight: CGFloat = 54
    /// To see the raw HTML
    private var rawTextView: UITextView!
    private var bottomStack: UIStackView!
    private var bottomStackHeightConstraint: NSLayoutConstraint!
    /// The state of the selection in the MarkupWKWebView, shown in the toolbar
    @Published var selectionState: SelectionState = SelectionState()
    @Published var selectedWebView: MarkupWKWebView?
    /// A binding of selectedWebView used by the MarkupToolbar and its coordinator.
    ///
    /// Since MarkupToolbar uses a SwiftUI-style binding to the selectedWebView, we need to use one
    /// for a UIKit-based app. The toolbar does not (and should not) set the selectedWebView, so this just
    /// lets us use the selectedWebView in UIKit like we use it as @State in the SwiftUI demo ContentView.
    /// We want selectedWebView to be optional in general, since one MarkupToolbar can be used with
    /// multiple MarkupWKWebViews, and it may lose focus as the app is being used. Note that in this demo
    /// app, the markupTookFocus method handled here sets the selectedWebView which in turn updates
    /// the toolbar due to its using the binding.
    var selectedWebViewBinding: Binding<MarkupWKWebView?> { Binding(get: { self.selectedWebView }, set: { self.selectedWebView = $0 }) }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeToolbar()
        initializeStackView()
    }
    
    func initializeToolbar() {
        toolbarHolder = UIView()
        toolbar = MarkupToolbar(
            selectionState: selectionState,
            selectedWebView: selectedWebViewBinding,
            markupDelegate: self,
            leftToolbar: AnyView(FileToolbar(selectionState: selectionState, selectedWebView: selectedWebViewBinding, fileToolbarDelegate: self))
        )
        add(swiftUIView: toolbar, to: toolbarHolder)
    }
    
    func initializeStackView() {
        // Populate the overall vertical stack with the toolbarHolder, webView, and rawTextView
        stack.addArrangedSubview(toolbarHolder)
        webView = MarkupWKWebView()
        stack.addArrangedSubview(webView)
        coordinator = MarkupCoordinator(selectionState: selectionState, markupDelegate: self, webView: webView)
        webView.configuration.userContentController.add(coordinator, name: "markup")
        webView.html = demoContent()
        bottomStack = UIStackView()
        bottomStack.isHidden = true
        bottomStack.axis = .vertical
        bottomStack.spacing = 8
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
        divider.backgroundColor = UIColor.systemGray5
        bottomStack.addArrangedSubview(divider)
        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: bottomStack.leadingAnchor, constant: 4),
            divider.trailingAnchor.constraint(equalTo: bottomStack.trailingAnchor, constant: 4),
        ])
        let label = UILabel()
        label.text = "Document HTML"
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemGray5
        bottomStack.addArrangedSubview(label)
        rawTextView = UITextView()
        rawTextView.contentInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        bottomStack.addArrangedSubview(rawTextView)
        stack.addArrangedSubview(bottomStack)
        bottomStackHeightConstraint = NSLayoutConstraint(item: bottomStack!, attribute: .height, relatedBy: .equal, toItem: webView, attribute: .height, multiplier: 1, constant: 0)
    }
    
    private func setRawText(_ handler: (()->Void)? = nil) {
        selectedWebView?.getPrettyHtml { html in
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
            selectedWebView?.setHtml(html) { content in
                self.setRawText()
            }
        } catch let error {
            print("Error loading html: \(error.localizedDescription)")
        }
    }
    
    private func openableURL(from url: URL) -> URL? {
        #if targetEnvironment(macCatalyst)
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
            var isStale = false
            let scopedUrl = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            return isStale ? nil : scopedUrl
        } catch let error {
            print("Error getting openableURL: \(error.localizedDescription)")
            return nil
        }
        #else
        return url
        #endif
    }
    
    private func demoContent() -> String? {
        guard
            let demoPath = Bundle.main.path(forResource: "demo", ofType: "html"),
            let url = openableURL(from: URL(fileURLWithPath: demoPath)),
            let html = try? String(contentsOf: url) else {
            return nil
        }
        url.stopAccessingSecurityScopedResource()
        return html
    }

}

extension ViewController: MarkupDelegate {
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        setRawText(handler)
    }
    
    func markupTookFocus(_ view: MarkupWKWebView) {
        selectedWebView = view
    }
    
    func markupInput(_ view: MarkupWKWebView) {
        // This is way too heavyweight, but it suits the purposes of the demo
        setRawText()
    }
    
}

extension ViewController: FileToolbarDelegate {
    
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

extension ViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        openExistingDocument(url: url)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
}
