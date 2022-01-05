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

/// The main view for the UIKitDemo.
///
/// Displays the MarkupToolbar at the top and the MarkupWKWebView at the bottom containing demo.html.
/// Acts as the MarkupDelegate to interact with editing operations as needed, and as the FileToolbarDelegate to interact with the FileToolbar.
class ViewController: UIViewController {
    @IBOutlet weak var stack: UIStackView!
    let markupEnv = MarkupEnv(style: .compact)
    var toolbarHolder: UIView!
    var webView: MarkupWKWebView!
    /// The MarkupCoordinator deals with the interaction with the MarkupWKWebView
    private var coordinator: MarkupCoordinator!
    /// The AnyView wrapper of MarkupToolbar is the SwiftUI component held in the toolbarHolder UIView
    private var toolbar: AnyView!
    private var subToolbar: AnyView!
    private let toolbarHeight: CGFloat = 54
    /// To see the raw HTML
    private var rawTextView: UITextView!
    private var bottomStack: UIStackView!
    private var bottomStackHeightConstraint: NSLayoutConstraint!
    /// The state of the selection in the MarkupWKWebView, shown in the toolbar
    var selectionState: SelectionState { markupEnv.selectionState }
    /// Which MarkupWKWebView we have selected and which the MarkupToolbar acts on
    var selectedWebView: MarkupWKWebView? { markupEnv.observedWebView.selectedWebView }
    /// Identify which type of SubToolbar is showing, or nil if none
    private let showSubToolbar = ShowSubToolbar()
    private let toolbarPreference = ToolbarPreference(style: .compact)
    // Note that we specify resoucesUrl when instantiating MarkupWebView so that we can demonstrate
    // loading of local resources in the edited document. That resource, a png, is packaged along
    // with the rest of the demo app resources, so we get more than we wanted from resourcesUrl,
    // but that's okay for demo. Normally, you would want to put resources in a subdirectory of
    // where your html file comes from, or in a directory that holds both the html file and all
    // of its resources.
    private let resourcesUrl: URL? = URL(string: Bundle.main.resourceURL!.path)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeToolbar()
        initializeStackView()
    }
    
    func initializeToolbar() {
        toolbarHolder = UIView()
        // We need to wrap MarkupToolbar in AnyView so we can set its environment
        toolbar = AnyView(
            MarkupToolbar(
                markupDelegate: self,
                leftToolbar: AnyView(FileToolbar(fileToolbarDelegate: self))
            )
                .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                .environmentObject(showSubToolbar)
                .environmentObject(markupEnv.toolbarPreference)
                .environmentObject(markupEnv.selectionState)
                .environmentObject(markupEnv.observedWebView)
        )
        add(swiftUIView: toolbar, to: toolbarHolder)
        subToolbar = AnyView(
            SubToolbar(markupDelegate: self)
                .environmentObject(showSubToolbar)
                .environmentObject(markupEnv.toolbarPreference)
                .environmentObject(markupEnv.selectionState)
                .environmentObject(markupEnv.observedWebView)
        )
    }
    
    func initializeStackView() {
        // Populate the overall vertical stack with the toolbarHolder, webView, and rawTextView
        stack.addArrangedSubview(toolbarHolder)
        webView = MarkupWKWebView(html: demoContent(), resourcesUrl: resourcesUrl, id: "Document", markupDelegate: self)
        overlayTop(swiftUIView: subToolbar, on: webView)
        stack.addArrangedSubview(webView)
        coordinator = MarkupCoordinator(selectionState: selectionState, markupDelegate: self, webView: webView)
        webView.configuration.userContentController.add(coordinator, name: "markup")
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
            selectedWebView?.setHtml(html) {
                self.setRawText()
            }
        } catch let error {
            print("Error loading html: \(error.localizedDescription)")
        }
    }
    
    private func demoContent() -> String {
        guard let demoUrl = Bundle.main.url(forResource: "demo", withExtension: "html") else { return "" }
        return (try? String(contentsOf: demoUrl)) ?? ""
    }

}

extension ViewController: MarkupDelegate {
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        markupEnv.observedWebView.selectedWebView = view
        setRawText(handler)
    }
    
    func markupInput(_ view: MarkupWKWebView) {
        // This is way too heavyweight, but it suits the purposes of the demo
        setRawText()
    }
    
    func markupImageAdded(url: URL) {
        print("Image added from \(url.path)")
    }
    
    func markupDropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        true
    }
    
    func markupDropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        UIDropProposal(operation: .copy)
    }
    
    func markupDropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        print("Dropping")
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
