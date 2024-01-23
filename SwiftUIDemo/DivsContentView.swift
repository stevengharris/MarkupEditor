//
//  DivsContentView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 12/20/23.
//

import SwiftUI
import MarkupEditor

struct DivsContentView: View {

    private var markupConfiguration: MarkupWKWebViewConfiguration
    private let divStructure = MarkupDivStructure()
    @ObservedObject var selectImage = MarkupEditor.selectImage
    @State private var rawText = NSAttributedString(string: "")
    @State private var documentPickerShowing: Bool = false
    @State private var rawShowing: Bool = false
    @State private var demoHtml: String
    @State private var selectedDivID: String?
    
    var body: some View {
        VStack(spacing: 0) {
            MarkupEditorView(markupDelegate: self, configuration: markupConfiguration, html: $demoHtml, id: "SpaDocument")
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
        .onAppear {
            MarkupEditor.leftToolbar = AnyView(FileToolbar(fileToolbarDelegate: self))
        }
        .onDisappear { MarkupEditor.selectedWebView = nil }
    }
    
    init() {
        /// Don't specify any top-level attributes for the editor div in this demo.
        markupConfiguration = MarkupWKWebViewConfiguration()
        markupConfiguration.topLevelAttributes = EditableAttributes.empty
        markupConfiguration.userCssFile = "demoDivs.css"
        markupConfiguration.userScriptFile = "demoDivs.js"
        _demoHtml = State(initialValue: "")
        initDivStructure()
    }
    
    private func initDivStructure() {
        let documentDivs: [HtmlDivHolder] = [
            Div1(name: "Chapter 1 - It Begins"),
            Div2(
                name: "We Have Liftoff",
                buttons: [
                    // We should be able to use SFSymbols here (e.g., 􀈑 and 􀋭), but they went missing.
                    // See https://feedbackassistant.apple.com/feedback/13537558.
                    // For now, fill in with Emojis.
                    HtmlButton(label: "🧐", targetId: "Section1", action: { actionInfo in inspect(actionInfo) }),
                    HtmlButton(label: "🗑️", targetId: "Section1", action: { actionInfo in delete(actionInfo) }),
                ]
            ),
            Div3(contents: "<p>This is an editable subsection with some <b>bold</b> text.</p>"),
            Div3(contents: "<p>This is also an editable subsection with a list.</p><ul><li><p>First item</p></li><li><p>Second item</p></li></ul>"),
            Div2(
                name: "Epilogue",
                buttons: [
                    // We should be able to use SFSymbols here (e.g., 􀈑 and 􀋭), but they went missing.
                    // See https://feedbackassistant.apple.com/feedback/13537558.
                    // For now, fill in with Emojis.
                    HtmlButton(label: "🧐", targetId: "Section2", action: { actionInfo in inspect(actionInfo) }),
                    HtmlButton(label: "🗑️", targetId: "Section2", action: { actionInfo in delete(actionInfo) }),
                ]
            ),
            Div3(contents: "<p>The demo is over</p>"),
        ]
        
        for div in documentDivs {
            divStructure.add(div)
        }
    }
    
    private func setRawText(_ handler: (()->Void)? = nil) {
        MarkupEditor.selectedWebView?.getHtml(clean: false, divID: selectedDivID) { html in
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
    
    private func delete(_ actionInfo: HtmlButton.ActionInfo) {
        print("Delete element: \(actionInfo.targetId ?? "nil")")
    }
    
    private func inspect(_ actionInfo: HtmlButton.ActionInfo) {
        print("Inspect element: \(actionInfo.targetId ?? "nil")")
    }
    
}

extension DivsContentView: MarkupDelegate {
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        
        MarkupEditor.selectedWebView = view
        for div in divStructure.divs {
            view.addDiv(div)
        }
        setRawText(handler)
    }
    
    func markupClicked(_ view: MarkupWKWebView) {
        view.getSelectionState { state in
            self.selectedDivID = state.isValid ? state.divid : nil
            print("Selected div ID: \(self.selectedDivID ?? "nil")")
            setRawText()
        }
    }
    
    func markupButtonClicked(_ view: MarkupWKWebView, id: String, rect: CGRect) {
        print("Button \(id) at \(rect) was clicked.")
        if let button = divStructure.button(for: id) {
            button.executeAction(view: view, rect: rect)
        }
    }
    
    func markupInput(_ view: MarkupWKWebView) {
        // This is way too heavyweight, but it suits the purposes of the demo
        setRawText()
    }
    
    func markupTookFocus(_ view: MarkupWKWebView) {
        print("Focused")
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

extension DivsContentView: FileToolbarDelegate {

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
