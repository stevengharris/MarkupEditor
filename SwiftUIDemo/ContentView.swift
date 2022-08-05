//
//  ContentView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 3/9/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI
import MarkupEditor
import UniformTypeIdentifiers

/// The main view for the SwiftUIDemo.
///
/// Displays the MarkupToolbar at the top and the MarkupWebView at the bottom containing demo.html.
/// Acts as the MarkupDelegate to interact with editing operations as needed, and as the FileToolbarDelegate to interact with the FileToolbar. 
struct ContentView: View {

    @EnvironmentObject var markupEnv: MarkupEnv
    @EnvironmentObject var selectImage: SelectImage
    @EnvironmentObject var showSubToolbar: ShowSubToolbar
    private var selectedWebView: MarkupWKWebView? { markupEnv.observedWebView.selectedWebView }
    @State private var rawText = NSAttributedString(string: "")
    @State private var documentPickerShowing: Bool = false
    @State private var rawShowing: Bool = false
    @State private var demoContent: String
    @State private var droppingImage: Bool = false
    // Note that we specify resoucesUrl when instantiating MarkupWebView so that we can demonstrate
    // loading of local resources in the edited document. That resource, a png, is packaged along
    // with the rest of the demo app resources, so we get more than we wanted from resourcesUrl,
    // but that's okay for demo. Normally, you would want to put resources in a subdirectory of
    // where your html file comes from, or in a directory that holds both the html file and all
    // of its resources.
    private let resourcesUrl: URL? = URL(string: Bundle.main.resourceURL!.path)

    var body: some View {
        VStack(spacing: 0) {
            MarkupToolbar(
                markupDelegate: self,
                leftToolbar: AnyView(
                    FileToolbar(fileToolbarDelegate: self)))
                .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
            Divider()
            MarkupWebView(markupDelegate: self, boundContent: $demoContent, resourcesUrl: resourcesUrl, id: "Document")
                .overlay(
                    SubToolbar(markupDelegate: self),
                    alignment: .topLeading)
                .onDrop(of: markupEnv.supportedImageTypes, isTargeted: $droppingImage) { (providers, location) -> Bool in
                    print("Dropping \(providers) at \(location)")
                    return true
                }
            if rawShowing {
                VStack {
                    Divider()
                    HStack {
                        Spacer()
                        Text("Document HTML")
                        Spacer()
                    }.background(Color(UIColor.systemGray5))
                    TextView(text: $rawText)
                        .font(Font.system(size: StyleContext.P.fontSize))
                        .padding([.top, .bottom, .leading, .trailing], 8)
                }
            }
        }
        .pick(isPresented: $documentPickerShowing, documentTypes: [.html], onPicked: openExistingDocument(url:), onCancel: nil)
        .pick(isPresented: $selectImage.value, documentTypes: markupEnv.supportedImageTypes, onPicked: imageSelected(url:), onCancel: nil)
        .environmentObject(showSubToolbar)
        .environmentObject(markupEnv)
        .environmentObject(markupEnv.toolbarPreference)
        .environmentObject(markupEnv.selectionState)
        .environmentObject(markupEnv.observedWebView)
        .environmentObject(markupEnv.selectImage)
        .onDisappear {
            markupEnv.observedWebView.selectedWebView = nil
        }
    }
    
    init(url: URL?) {
        if let url = url {
            _demoContent = State(initialValue: (try? String(contentsOf: url)) ?? "")
        } else {
            _demoContent = State(initialValue: "")
        }
    }
    
    private func setRawText(_ handler: (()->Void)? = nil) {
        selectedWebView?.getHtml { html in
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
        demoContent = (try? String(contentsOf: url)) ?? ""
    }
    
    private func imageSelected(url: URL) {
        guard let view = selectedWebView else { return }
        markupImageToAdd(view, url: url)
    }
    
}

extension ContentView: MarkupDelegate {
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        markupEnv.observedWebView.selectedWebView = view
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
        if (alert) {
            AudioPlayer.shared.playSound(filename: "alert.wav")
        }
    }

}

extension ContentView: FileToolbarDelegate {
    
    func newDocument(handler: ((URL?)->Void)? = nil) {
        selectedWebView?.emptyDocument() {
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
