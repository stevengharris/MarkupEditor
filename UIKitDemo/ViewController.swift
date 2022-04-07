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
import Combine

/// The main view for the UIKitDemo.
///
/// Displays the MarkupToolbar at the top and the MarkupWKWebView at the bottom containing demo.html.
/// Acts as the MarkupDelegate to interact with editing operations as needed, and as the FileToolbarDelegate to interact with the FileToolbar.
///
/// Because the MarkupToolbar and its associated SubToolbar are written in SwiftUI, there is a ton of SwiftUI-driven cruft in this method
/// compared to what is needed in "pure" SwiftUI. For example, the MarkupCoordinator is transparently hooked up in SwiftUI by the
/// MarkupWebView. Worse, the support for local image selection uses a SwiftUI-style piece of state that is toggled off and on to
/// determine if a picker should be shown, and that has to be hooked into the UIKit world using a Combine AnyCancellable. It's just
/// crazy for a UIKit app, but I'm leaving it here for now.  I would really recommend creating a new UIKit version of MarkupToolbar.
/// The MarkupWKWebView doesn't have any SwiftUI dependencies and can just be used directly.
class ViewController: UIViewController {
    var stack: UIStackView!
    var markupEnv: MarkupEnv!
    var toolbarHolder: UIView!
    var webView: MarkupWKWebView!
    /// The MarkupCoordinator deals with the interaction with the MarkupWKWebView
    private var coordinator: MarkupCoordinator!
    /// The AnyView wrapper of MarkupToolbar is the SwiftUI component held in the toolbarHolder UIView
    private var toolbar: AnyView!
    private var subToolbar: AnyView!
    private var subToolbarUIView: UIView!
    /// To see the raw HTML
    private var rawTextView: UITextView!
    private var bottomStack: UIStackView!
    private var bottomStackHeightConstraint: NSLayoutConstraint!
    /// The state of the selection in the MarkupWKWebView, shown in the toolbar
    var selectionState: SelectionState { markupEnv.selectionState }
    /// Which MarkupWKWebView we have selected and which the MarkupToolbar acts on
    var selectedWebView: MarkupWKWebView? { markupEnv.observedWebView.selectedWebView }
    /// Toggle whether the file selector should be shown to select a local image
    var selectImageCancellable: AnyCancellable?
    /// Identify which type of SubToolbar is showing, or nil if none
    var showSubToolbar: ShowSubToolbar { markupEnv.showSubToolbar }
    var showSubToolbarCancellable: AnyCancellable?
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
        // Get the markupEnv from the SceneDelegate.
        // We need the markupEnv available in SceneDelegate so we can invoke menu actions.
        markupEnv = (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.markupEnv
        initializePickers()
        initializeToolbar()
        initializeStackView()
    }
    
    func initializePickers() {
        selectImageCancellable = markupEnv.selectImage.$value.sink { [weak self] value in
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
    
    /// Set up the MarkupToolbar at the top of the view, with a divider below it. Create the subToolbar which
    /// will be overlayed on the MarkupWKWebView later.
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
        toolbarHolder.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbarHolder)
        NSLayoutConstraint.activate([
            toolbarHolder.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbarHolder.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: (toolbarPreference.height() + 2)),
            toolbarHolder.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor),
            toolbarHolder.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor)
        ])
        let divider = divider(in: view)
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: toolbarHolder.bottomAnchor, constant: 1)
        ])
        subToolbar = AnyView(
            SubToolbar(markupDelegate: self)
                .environmentObject(markupEnv.toolbarPreference)
                .environmentObject(markupEnv.selectionState)
                .environmentObject(markupEnv.observedWebView)
                .environmentObject(markupEnv.showSubToolbar)
                .environmentObject(markupEnv.selectImage)
        )
    }
    
    /// Set up the stack below the MarkupToolbar. The stack contains the MarkupWKWebView and the rawTextView.
    ///
    /// The rawTextView height toggles as the raw text is shown.
    ///
    /// The subToolbar is overlayed on the MarkupWKWebView. This way it covers the content of that view when it is
    /// turned off and on, as opposed to having the stack layout adjust.
    func initializeStackView() {
        // Create the stack
        stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .fill
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: toolbarHolder.bottomAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor),
            stack.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor)
        ])
        // Create the webView and overlay the subToolbar
        webView = MarkupWKWebView(html: demoContent(), resourcesUrl: resourcesUrl, id: "Document", markupDelegate: self)
        subToolbarUIView = overlayTop(swiftUIView: subToolbar, on: webView, height: toolbarPreference.height())
        subToolbarUIView.isHidden = true
        // Monitor changes to the subToolbar type held in the markupEnv. The value will change as when one of
        // the InsertToolbar buttons is pressed. This is a "natural" way to do things in SwiftUI, but we can
        // use Combine in UIKit to get the same effect.
        showSubToolbarCancellable = markupEnv.showSubToolbar.$type.sink { [weak self] type in
            if type == .none {
                self?.subToolbarUIView.isHidden = true
            } else {
                self?.subToolbarUIView.isHidden = false
            }
        }
        stack.addArrangedSubview(webView)
        // Set up the MarkupCoordinator. This is done transparently in SwiftUI by the WebView.
        coordinator = MarkupCoordinator(selectionState: selectionState, markupDelegate: self, webView: webView)
        webView.configuration.userContentController.add(coordinator, name: "markup")
        // Set up the bottom stack to hold the rawTextView and some decoration above it. Make the
        // bottom stack the same height as the webView so the overall stack can adjust nicely.
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
        rawTextView.contentInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        bottomStack.addArrangedSubview(rawTextView)
        stack.addArrangedSubview(bottomStack)
        bottomStackHeightConstraint = NSLayoutConstraint(item: bottomStack!, attribute: .height, relatedBy: .equal, toItem: webView, attribute: .height, multiplier: 1, constant: 1)
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
    
    private func imageSelected(url: URL) {
        guard let view = selectedWebView else { return }
        markupImageToAdd(view, url: url)
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
    
    /// Override the default behavior for when the MarkupEditor encounters an error.
    ///
    /// In the event of a MUError.Alert, play an alert sound.
    func markupError(code: String, message: String, info: String?, alert: Bool) {
        print("Error \(code): \(message)")
        if let info = info { print(" \(info)") }
        if (alert) {
            AudioPlayer.shared.playSound(filename: "alert.wav")
        }
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
    
    /// Handle the two cases for the document picker: selecting a local image and opening an existing html document.
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if (markupEnv.selectImage.value) {
            markupEnv.selectImage.value = false
            imageSelected(url: url)
        } else {
            openExistingDocument(url: url)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        markupEnv.selectImage.value = false
        controller.dismiss(animated: true, completion: nil)
    }
    
}
