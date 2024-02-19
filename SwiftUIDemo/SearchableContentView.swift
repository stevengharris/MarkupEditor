//
//  SearchableContentView.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/6/23.
//

import SwiftUI
import MarkupEditor

/// Similar to DemoContentView, but with a SearchBar at the top to demo search functionality.
///
/// Displays the MarkupEditorView containing demo.html. By default, the MarkupEditorView shows the MarkupToolbar at the top.
///
/// Acts as the MarkupDelegate to interact with editing operations as needed.
///
/// A local png image is packaged along with the rest of the demo app resources for demo purposes only.
/// Normally, you would want to put resources in a subdirectory of where your html file comes from, or in
/// a directory that holds both the html file and all of its resources. When you do that, you would specify
/// `resourcesUrl` when  instantiating MarkupEditorView, so that the \<img src=...> tag can identify
/// the `src` for the image relative to your html document.
struct SearchableContentView: View {

    @ObservedObject var selectImage = MarkupEditor.selectImage
    @State private var documentPickerShowing: Bool = false
    @State private var demoHtml: String
    
    var body: some View {
        VStack(spacing: 0) {
            SearchBar()
                .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            MarkupEditorView(markupDelegate: self, html: $demoHtml, id: "Document")
        }
        .pick(isPresented: $selectImage.value, documentTypes: MarkupEditor.supportedImageTypes, onPicked: imageSelected(url:), onCancel: nil)
        .onDisappear { MarkupEditor.selectedWebView = nil }
    }
    
    init() {
        if let demoUrl = Bundle.main.resourceURL?.appendingPathComponent("demo.html") {
            _demoHtml = State(initialValue: (try? String(contentsOf: demoUrl)) ?? "")
        } else {
            _demoHtml = State(initialValue: "")
        }
    }
    
    private func imageSelected(url: URL) {
        guard let view = MarkupEditor.selectedWebView else { return }
        markupImageToAdd(view, url: url)
    }
    
}

extension SearchableContentView: MarkupDelegate {
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        MarkupEditor.selectedWebView = view
        view.becomeFirstResponderIfReady()  // We don't want the SearchBar to be firstResponder
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
