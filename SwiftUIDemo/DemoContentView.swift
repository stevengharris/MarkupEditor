//
//  DemoContentView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 3/9/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import MarkupEditor

/// The main view for the SwiftUIDemo.
///
/// Displays the MarkupEditorView containing demo.html and a TextView to display the raw HTML that can be toggled
/// on and off from the FileToolbar. By default, the MarkupEditorView shows the MarkupToolbar at the top.
/// 
/// Acts as the MarkupDelegate to interact with editing operations as needed, and as the FileToolbarDelegate to interact
/// with the FileToolbar.
///
/// A local png image is packaged along with the rest of the demo app resources for demo purposes only.
/// Normally, you would want to put resources in a subdirectory of where your html file comes from, or in
/// a directory that holds both the html file and all of its resources. When you do that, you would specify
/// `resourcesUrl` when  instantiating MarkupEditorView, so that the \<img src=...> tag can identify
/// the `src` for the image relative to your html document.
struct DemoContentView: View {

    var compatibleSystemGray5: Color {
        #if os(macOS)
        return Color(nsColor: NSColor.unemphasizedSelectedContentBackgroundColor)
        #else
        // This is for iOS, iPadOS, tvOS
        return Color(uiColor: UIColor.systemGray5)
        #endif
    }
    
    @ObservedObject var selectImage = MarkupEditor.selectImage
    @State private var rawText = ""
    @State private var documentPickerShowing: Bool = false
    @State private var rawShowing: Bool = false
    @State private var demoHtml: String
    @State private var hasChanges = false
    @State private var currentFileURL: URL?
    /// The `markupConfiguration` holds onto the name of any userResourceFiles we set in init.
    private let markupConfiguration = MarkupWKWebViewConfiguration()
    
    var body: some View {
        VStack(spacing: 0) {
            MarkupEditorView(markupDelegate: self, configuration: markupConfiguration, html: $demoHtml, placeholder: "Add document content...", id: "Document")
            if rawShowing {
                VStack {
                    Divider()
                    HStack {
                        Spacer()
                        Text("Document HTML")
                        Spacer()
                    }.background(compatibleSystemGray5)
                    ScrollView {
                        Text(rawText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(Font.system(size: StyleContext.P.fontSize))
                            .padding([.top, .bottom, .leading, .trailing], 8)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuNewDocument)) { _ in
            handleNew()
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuOpenDocument)) { _ in
            handleOpen()
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuSaveDocument)) { _ in
            handleSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuSaveAsDocument)) { _ in
            handleSaveAs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuShowHtml)) { _ in
            rawDocument()
        }
#if !os(macOS)
        .pick(isPresented: $documentPickerShowing, documentTypes: [.html], onPicked: openExistingDocument(url:), onCancel: nil)
        .pick(isPresented: $selectImage.value, documentTypes: MarkupEditor.supportedImageTypes, onPicked: imageSelected(url:), onCancel: nil)
#endif
#if os(iOS) && !targetEnvironment(macCatalyst)
        // Only add the FileToolbar in for iOS, because the New, Open, Save, SaveAs, and Show HTML are available in the menu
        // on MacOS and Mac Catalyst.
        // If we want actions in the leftToolbar to cause this view to update, then we need to set it up in onAppear, not init
        .onAppear { MarkupEditor.leftToolbar = AnyView(FileToolbar(fileToolbarDelegate: self)) }
#endif
        .onDisappear { MarkupEditor.selectedWebView = nil }
    }
    
    init() {
        if let demoUrl = Bundle.main.resourceURL?.appendingPathComponent("demo.html") {
            _demoHtml = State(initialValue: (try? String(contentsOf: demoUrl)) ?? "")
        } else {
            _demoHtml = State(initialValue: "")
        }
        // Identify any resources coming from the app bundle that need to be co-located with
        // the document. In this case, we have an image that we load from within demo.html.
        markupConfiguration.userResourceFiles = ["steve.png"]
    }
    
    
    
    private func setRawText(_ handler: (()->Void)? = nil) {
        MarkupEditor.selectedWebView?.getHtml { html in
            rawText = html ?? ""
            handler?()
        }
    }
    
    private func openExistingDocument(url: URL) {
        demoHtml = (try? String(contentsOf: url)) ?? ""
    }
    
    private func imageSelected(url: URL) {
        guard let view = MarkupEditor.selectedWebView else { return }
        markupImageToAdd(view, url: url)
    }

    // MARK: - File operations (driven by menu notifications on macOS)

    /// Present a save/discard/cancel alert if the document has unsaved changes.
    /// Calls the completion with true to proceed, false to cancel.
    /// On macOS, runs modally and calls completion synchronously.
    /// On Catalyst, presents a UIAlertController and calls completion asynchronously.
    private func checkSave(then proceed: @escaping (Bool) -> Void) {
        guard hasChanges else {
            proceed(true)
            return
        }
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes to this document?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            handleSave()
            proceed(true)
        case .alertSecondButtonReturn:
            hasChanges = false
            proceed(true)
        default:
            proceed(false)
        }
        #else
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootVC = window.rootViewController else {
            proceed(true)
            return
        }
        let alert = UIAlertController(
            title: "Do you want to save the changes to this document?",
            message: "Your changes will be lost if you don't save them.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [self] _ in
            handleSave()
            proceed(true)
        })
        alert.addAction(UIAlertAction(title: "Don't Save", style: .destructive) { [self] _ in
            hasChanges = false
            proceed(true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            proceed(false)
        })
        rootVC.present(alert, animated: true)
        #endif
    }

    private func handleNew() {
        checkSave { [self] shouldProceed in
            guard shouldProceed else { return }
            MarkupEditor.selectedWebView?.emptyDocument {
                setRawText()
            }
            currentFileURL = nil
            hasChanges = false
        }
    }

    private func handleOpen() {
        checkSave { [self] shouldProceed in
            guard shouldProceed else { return }
            #if os(macOS)
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.html]
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            guard panel.runModal() == .OK, let url = panel.url else { return }
            loadHtml(from: url)
            #else
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first,
                  let rootVC = window.rootViewController else { return }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.html])
            picker.allowsMultipleSelection = false
            picker.delegate = OpenPickerDelegate.shared
            OpenPickerDelegate.shared.onPick = { urls in
                guard let url = urls.first else { return }
                self.loadHtml(from: url)
            }
            rootVC.present(picker, animated: true)
            #endif
        }
    }

    private func loadHtml(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let html = try String(contentsOf: url, encoding: .utf8)
            MarkupEditor.selectedWebView?.setHtml(html)
            currentFileURL = url
            hasChanges = false
            setRawText()
        } catch {
            #if os(macOS)
            let alert = NSAlert(error: error)
            alert.runModal()
            #endif
        }
    }

    private func handleSave() {
        if let url = currentFileURL {
            saveHtml(to: url)
        } else {
            showSavePanel()
        }
    }

    private func handleSaveAs() {
        showSavePanel()
    }

    private func showSavePanel() {
        #if os(macOS)
        guard let window = NSApplication.shared.keyWindow else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = currentFileURL?.lastPathComponent ?? "Untitled.html"
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            saveHtml(to: url)
            currentFileURL = url
        }
        #else
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootVC = window.rootViewController else { return }
        // On Catalyst, write to a temporary file then present a document export picker
        // so the user chooses the destination.
        MarkupEditor.selectedWebView?.getHtml { [self] html in
            guard let html else { return }
            let fileName = currentFileURL?.lastPathComponent ?? "Untitled.html"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try html.write(to: tempURL, atomically: true, encoding: .utf8)
                let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
                picker.delegate = SavePickerDelegate.shared
                SavePickerDelegate.shared.onPick = { urls in
                    guard let url = urls.first else { return }
                    self.currentFileURL = url
                    self.hasChanges = false
                }
                rootVC.present(picker, animated: true)
            } catch {
                // Temp file write failed
            }
        }
        #endif
    }

    private func saveHtml(to url: URL) {
        MarkupEditor.selectedWebView?.getHtml { html in
            guard let html else { return }
            do {
                try html.write(to: url, atomically: true, encoding: .utf8)
                hasChanges = false
            } catch {
                #if os(macOS)
                let alert = NSAlert(error: error)
                alert.runModal()
                #endif
            }
        }
    }

}

#if !os(macOS)
/// Lightweight delegate for UIDocumentPickerViewController used by Open.
private class OpenPickerDelegate: NSObject, UIDocumentPickerDelegate {
    static let shared = OpenPickerDelegate()
    var onPick: (([URL]) -> Void)?

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onPick?(urls)
        onPick = nil
    }
}

/// Lightweight delegate for UIDocumentPickerViewController used by Save/Save As.
private class SavePickerDelegate: NSObject, UIDocumentPickerDelegate {
    static let shared = SavePickerDelegate()
    var onPick: (([URL]) -> Void)?

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onPick?(urls)
        onPick = nil
    }
}
#endif

extension DemoContentView: MarkupDelegate {
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        MarkupEditor.selectedWebView = view
        setRawText(handler)
    }
    
    func markupInput(_ view: MarkupWKWebView) {
        hasChanges = true
        // This is way too heavyweight, but it suits the purposes of the demo
        view.getSelectionState() { selectionState in
            //Logger.coordinator.debug("* selectionChange")
            MarkupEditor.selectionState.reset(from: selectionState)
            setRawText()
        }
    }
    
    /// Callback received after a local image has been added to the document.
    ///
    /// Note the URL will be to a copy of the image you identified, copied to the caches directory for the app.
    /// You may want to copy this image to a proper storage location. For demo, I'm leaving the print statement
    /// in to highlight what happened.
    func markupImageAdded(url: URL) {
        print("Image added from \(url.path)")
    }


}

extension DemoContentView: FileToolbarDelegate {

    func newDocument(handler: ((URL?)->Void)? = nil) {
        MarkupEditor.selectedWebView?.emptyDocument() {
            setRawText()
        }
    }

    func existingDocument(handler: ((URL?)->Void)? = nil) {
        documentPickerShowing.toggle()
    }

    func rawDocument() {
        withAnimation(.easeInOut(duration: 0.25)) { rawShowing.toggle() }
    }

}
