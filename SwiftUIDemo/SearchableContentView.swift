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
struct SearchableContentView: View {

    @ObservedObject var selectImage = MarkupEditor.selectImage
    @State private var documentPickerShowing: Bool = false
    @State private var demoHtml: String
    
    // Note that we specify resourcesUrl when instantiating MarkupEditorView so that we can demonstrate
    // loading of local resources in the edited document. That resource, a png, is packaged along
    // with the rest of the demo app resources, so we get more than we wanted from resourcesUrl,
    // but that's okay for demo. Normally, you would want to put resources in a subdirectory of
    // where your html file comes from, or in a directory that holds both the html file and all
    // of its resources.
    private let resourcesUrl: URL? = URL(string: Bundle.main.resourceURL!.path)
    
    var body: some View {
        VStack(spacing: 0) {
            SearchBar()
                .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            MarkupEditorView(markupDelegate: self, html: $demoHtml, resourcesUrl: resourcesUrl, id: "Document")
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
