//
//  ContentView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 3/9/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI
import MarkupEditor

/// The main view for the SwiftUIDemo.
///
/// Displays the MarkupEditorView containing demo.html and a TextView to display the raw HTML that can be toggled
/// on and off from the FileToolbar. By default, the MarkupEditorView shows the MarkupToolbar at the top.
/// 
/// Acts as the MarkupDelegate to interact with editing operations as needed, and as the FileToolbarDelegate to interact
/// with the FileToolbar.
struct ContentView: View {

    @ObservedObject var selectImage = MarkupEditor.selectImage
    @State private var rawText = NSAttributedString(string: "")
    @State private var documentPickerShowing: Bool = false
    @State private var rawShowing: Bool = false
    @State private var demoHtml: String
    //@State private var droppingImage: Bool = false
    
    // Note that we specify resourcesUrl when instantiating MarkupEditorView so that we can demonstrate
    // loading of local resources in the edited document. That resource, a png, is packaged along
    // with the rest of the demo app resources, so we get more than we wanted from resourcesUrl,
    // but that's okay for demo. Normally, you would want to put resources in a subdirectory of
    // where your html file comes from, or in a directory that holds both the html file and all
    // of its resources.
    private let resourcesUrl: URL? = URL(string: Bundle.main.resourceURL!.path)
    
    var body: some View {
        //if #available(macCatalyst 15.0, *) {
        //    let _ = Self._printChanges()
        //}
        VStack(spacing: 0) {
            MarkupEditorView(markupDelegate: self, html: $demoHtml, resourcesUrl: resourcesUrl, id: "Document")
            if rawShowing {
                VStack {
                    Divider()
                    HStack {
                        Spacer()
                        Text("Document HTML")
                        Spacer()
                    }.background(Color(UIColor.systemGray5))
                    TextView(text: $rawText, isEditable: false)
                        .font(Font.system(size: StyleContext.P.fontSize))
                        .padding([.top, .bottom, .leading, .trailing], 8)
                }
            }
        }
        .pick(isPresented: $documentPickerShowing, documentTypes: [.html], onPicked: openExistingDocument(url:), onCancel: nil)
        .pick(isPresented: $selectImage.value, documentTypes: MarkupEditor.supportedImageTypes, onPicked: imageSelected(url:), onCancel: nil)
        // If we want actions in the leftToolbar to cause this view to update, then we need to set it up in onAppear, not init
        .onAppear { MarkupEditor.leftToolbar = AnyView(FileToolbar(fileToolbarDelegate: self)) }
        .onDisappear { MarkupEditor.selectedWebView = nil }
    }
    
    init() {
        if let demoUrl = Bundle.main.resourceURL?.appendingPathComponent("demo.html") {
            _demoHtml = State(initialValue: (try? String(contentsOf: demoUrl)) ?? "")
        } else {
            _demoHtml = State(initialValue: "")
        }
    }
    
    private func setRawText(_ handler: (()->Void)? = nil) {
        MarkupEditor.selectedWebView?.getHtml { html in
            rawText = attributedString(from: html ?? "")
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
        demoHtml = (try? String(contentsOf: url)) ?? ""
    }
    
    private func imageSelected(url: URL) {
        guard let view = MarkupEditor.selectedWebView else { return }
        markupImageToAdd(view, url: url)
    }
    
}

extension ContentView: MarkupDelegate {
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        MarkupEditor.selectedWebView = view
        setRawText(handler)
    }
    
    func markupInput(_ view: MarkupWKWebView) {
        // This is way too heavyweight, but it suits the purposes of the demo
        setRawText()
    }
    
    /// Callback received after a local image has been added to the document.
    ///
    /// Note the URL will be to a copy of the image you identified, copied to the caches directory for the app.
    /// You may want to copy this image to a proper storage location. For demo, I'm leaving the print statement
    /// in to highlight what happened.
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

extension ContentView: FileToolbarDelegate {

    func newDocument(handler: ((URL?)->Void)? = nil) {
        MarkupEditor.selectedWebView?.emptyDocument() {
            setRawText()
        }
    }

    func existingDocument(handler: ((URL?)->Void)? = nil) {
        documentPickerShowing.toggle()
    }

    func rawDocument() {
        withAnimation { rawShowing.toggle()}
    }

}
