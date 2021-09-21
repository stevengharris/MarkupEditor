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

    private let markupEnv = MarkupEnv(style: .compact)
    private var selectedWebView: MarkupWKWebView? { markupEnv.observedWebView.selectedWebView }
    private let showSubToolbar = ShowSubToolbar()
    @State private var rawText = NSAttributedString(string: "")
    @State private var pickerShowing: Bool = false
    @State private var rawShowing: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            MarkupToolbar(
                markupDelegate: self,
                leftToolbar: AnyView(
                    FileToolbar(fileToolbarDelegate: self)))
                .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
            Divider()
            MarkupWebView(markupDelegate: self, initialContent: demoContent())
                .overlay(
                    SubToolbar(markupDelegate: self),
                    alignment: .topLeading)
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
        .pick(isPresented: $pickerShowing, documentTypes: [.html], onPicked: openExistingDocument(url:), onCancel: nil)
        .environmentObject(showSubToolbar)
        .environmentObject(markupEnv.toolbarPreference)
        .environmentObject(markupEnv.selectionState)
        .environmentObject(markupEnv.observedWebView)
    }
    
    private func setRawText(_ handler: (()->Void)? = nil) {
        selectedWebView?.getPrettyHtml { html in
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
        do {
            let html = try String(contentsOf: url, encoding: .utf8)
            selectedWebView?.setHtml(html) { content in
                self.setRawText()
            }
        } catch let error {
            print("Error loading html: \(error.localizedDescription)")
        }
    }
    
    private func openableURL(from url: URL) -> URL? {
        #if targetEnvironment(macCatalyst)
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
            var isStale = false
            let scopedUrl = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            return isStale ? nil : scopedUrl
        } catch let error {
            print("Error getting openableURL: \(error.localizedDescription)")
            return nil
        }
        #else
        return url
        #endif
    }
    
    private func demoContent() -> String? {
        guard
            let demoPath = Bundle.main.path(forResource: "demo", ofType: "html"),
            let url = openableURL(from: URL(fileURLWithPath: demoPath)),
            let html = try? String(contentsOf: url) else {
            return nil
        }
        url.stopAccessingSecurityScopedResource()
        return html
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

}

extension ContentView: FileToolbarDelegate {
    
    func newDocument(handler: ((URL?)->Void)? = nil) {
        selectedWebView?.emptyDocument() {
            setRawText()
        }
    }
    
    func existingDocument(handler: ((URL?)->Void)? = nil) {
        pickerShowing.toggle()
    }
    
    func rawDocument() {
        withAnimation { rawShowing.toggle()}
    }
    
}


