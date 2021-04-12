//
//  ContentView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 3/9/21.
//

import SwiftUI
import MarkupEditor

struct ContentView: View {

    @StateObject var selectionState = SelectionState()
    @State var selectedWebView: MarkupWKWebView?
    
    @State private var rawText = NSAttributedString(string: "")
    
    var body: some View {
        VStack(spacing: 0) {
            MarkupToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, markupUIDelegate: self)
            MarkupWebView(selectionState: selectionState, selectedWebView: $selectedWebView, markupEventDelegate: self, initialContent: "<p>Hello <strong>bold</strong> <em>SwiftUI</em> world!</p>")
            Divider()
            TextView(text: $rawText)
                .font(Font.system(size: StyleContext.H4.fontSize))
                .padding([.top, .bottom, .leading, .trailing], 8)
        }
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
    
    func markupClicked(_ view: MarkupWKWebView) {
        // If the selection is in a link and not across multiple characters, then let the markupUIDelegate decide what to do.
        // The default behavior for the markupUIDelegate is to open the href in selectionState.
        if selectionState.isFollowable {
            markupLinkSelected(view, selectionState: selectionState)
        }
        // If the selection is in an image, let the markupUIDelegate decide what to do
        if selectionState.isInImage {
            markupImageSelected(view, selectionState: selectionState)
        }
    }

}

extension ContentView: MarkupUIDelegate {
    
    func markupNewDocument(handler: ((URL?)->Void)? = nil) {}
    func markupExistingDocument(handler: ((URL?)->Void)? = nil) {}
    func markupSaveDocument() {}
    
}
