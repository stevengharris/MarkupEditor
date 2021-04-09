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
    
    enum RawFormat: String, CaseIterable {
        case HTML
        case Markdown
        case RoundTrip
    }
    @State private var rawText = NSMutableAttributedString(string: "")
    @State private var rawFormat: RawFormat = .HTML
    var body: some View {
        VStack(spacing: 0) {
            MarkupToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, markupUIDelegate: self)
            MarkupWebView(selectionState: selectionState, selectedWebView: $selectedWebView, markupEventDelegate: self, initialContent: "<p>Hello <strong>bold</strong> <em>SwiftUI</em> world!</p>")
            Divider()
            VStack(spacing: 2) {
                Spacer()
                Picker(selection: $rawFormat, label: Text("")) {
                    ForEach(RawFormat.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .disabled(selectedWebView == nil)
                .scaledToFit()
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: rawFormat, perform: { format in
                    switch format {
                    case .HTML:
                        selectedWebView?.getPrettyHtml { html in
                            rawText = NSMutableAttributedString(string: html ?? "")
                        }
                    case .Markdown:
                        selectedWebView?.getMarkdown { markdown in
                            rawText = NSMutableAttributedString(string: markdown ?? "")
                        }
                    case .RoundTrip:
                        selectedWebView?.getRoundTrip { roundTrip in
                            rawText = NSMutableAttributedString(string: roundTrip ?? "")
                        }
                    }
                })
                TextView(text: $rawText)
            }
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
        switch rawFormat {
        case .HTML:
            selectedWebView?.getPrettyHtml { html in
                rawText = NSMutableAttributedString(string: html ?? "")
            }
        case .Markdown:
            selectedWebView?.getMarkdown { markdown in
                rawText = NSMutableAttributedString(string: markdown ?? "")
            }
        case .RoundTrip:
            selectedWebView?.getRoundTrip { roundTrip in
                rawText = NSMutableAttributedString(string: roundTrip ?? "")
            }
        }
    }
    
    func markup(_ view: MarkupWKWebView, contentDidChange content: String) {
        rawFormat = .HTML
        rawText = NSMutableAttributedString(string: content)
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
    func markupSaveDocument() {
        
    }
    
}
