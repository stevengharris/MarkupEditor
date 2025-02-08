//
//  CustomContentView.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/13/24.
//

import SwiftUI
import MarkupEditor

/// Identical to the DemoContentView, except also demonstrating the use of custom.js and custom.css
/// to customize style and add a user script that returns the word count of the document.
struct CustomContentView: View {

    @ObservedObject var selectImage = MarkupEditor.selectImage
    @State private var rawText = NSAttributedString(string: "")
    @State private var documentPickerShowing: Bool = false
    @State private var rawShowing: Bool = false
    @State private var demoHtml: String
    @State private var wordCount: Int = 0
    /// The `markupConfiguration` holds onto the userCSSFile and userScriptFile we set in init.
    private let markupConfiguration = MarkupWKWebViewConfiguration()
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Label("Word count: \(wordCount)", systemImage: "text.word.spacing")
            Spacer()
            MarkupEditorView(markupDelegate: self, configuration: markupConfiguration, html: $demoHtml, id: "Document")
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
        // Identify the the css and js that will be loaded after markup.html is fully loaded.
        // For demo purposes, both files are included in SharedDemo. See markupLoaded below
        // where the classes are assigned using a call to `assignClasses` in the MarkupWKWebView.
        markupConfiguration.userCssFile = "custom.css"
        markupConfiguration.userScriptFile = "custom.js"
    }
    
    private func setRawText(_ handler: (()->Void)? = nil) {
        MarkupEditor.selectedWebView?.getHtml { html in
            rawText = attributedString(from: html ?? "")
            MarkupEditor.selectedWebView?.wordcount { count in wordCount = count ?? 0 }
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

extension CustomContentView: MarkupDelegate {
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        // Now that the code in markup.js and custom.js has been loaded, and the markup.css and custom.css
        // have been set, we can invoke wordCount to display the number of words in the document.
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


}

extension CustomContentView: FileToolbarDelegate {

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
