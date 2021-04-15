//
//  ContentView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 3/9/21.
//

import SwiftUI
import MarkupEditor
import UniformTypeIdentifiers

struct ContentView: View {

    @StateObject var selectionState = SelectionState()
    @State var selectedWebView: MarkupWKWebView?
    
    @State private var rawText = NSAttributedString(string: "")
    
    @State private var pickerShowing: Bool = false
    @State private var fileUrl: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            // Use the standard MarkupToolbar with a FileToolbar on the left side
            MarkupToolbar(
                selectionState: selectionState,
                selectedWebView: $selectedWebView,
                markupUIDelegate: self,
                leftToolbar: AnyView(FileToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, fileToolbarDelegate: self))
            )
            MarkupWebView(selectionState: selectionState, selectedWebView: $selectedWebView, markupEventDelegate: self, markupUIDelegate: self, initialContent: "<p>Hello <b>bold</b> <i>SwiftUI</i> world!</p>")
            Divider()
            TextView(text: $rawText)
                .font(Font.system(size: StyleContext.P.fontSize))
                .padding([.top, .bottom, .leading, .trailing], 8)
        }
        .pick(isPresented: $pickerShowing, documentTypes: [.html], onPicked: openExistingDocument(url:), onCancel: nil)
    }
    
    private func setRawText() {
        selectedWebView?.getPrettyHtml { html in
            rawText = attributedString(from: html ?? "")
        }
    }
    
    private func attributedString(from string: String) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: StyleContext.P.fontSize, weight: .regular)
        let attributes = [NSAttributedString.Key.font: font]
        return NSAttributedString(string: string, attributes: attributes)
    }
    
    private func openExistingDocument(url: URL) {
        do {
            let html = try String(contentsOf: url, encoding: .utf8)
            fileUrl = url
            selectedWebView?.setHtml(html) { content in
                self.setRawText()
            }
        } catch let error {
            print("Error loading html: \(error.localizedDescription)")
        }
    }
    
    
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        ContentView()
    }
    
}

extension ContentView: MarkupEventDelegate {
    
    func markupTookFocus(_ view: MarkupWKWebView) {
        selectedWebView = view
    }
    
    func markupInput(_ view: MarkupWKWebView) {
        // This is way too heavyweight, but it suits the purposes of the demo
        setRawText()
    }
    
    func markup(_ view: MarkupWKWebView, contentDidChange content: String) {
        rawText = attributedString(from: content)
    }

}

extension ContentView: MarkupUIDelegate {}

extension ContentView: FileToolbarDelegate {
    
    func newDocument(handler: ((URL?)->Void)? = nil) {
        fileUrl = nil
        selectedWebView?.emptyDocument() {
            setRawText()
        }
    }
    
    func existingDocument(handler: ((URL?)->Void)? = nil) {
        pickerShowing.toggle()
    }
    
    func saveDocument() {}
    
}


