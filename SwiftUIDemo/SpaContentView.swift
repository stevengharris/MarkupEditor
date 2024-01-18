//
//  SpaContentView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 12/20/23.
//

import SwiftUI
import MarkupEditor

struct SpaContentView: View {

    private var markupConfiguration: MarkupWKWebViewConfiguration
    private let divStructure = MarkupDivStructure()
    @ObservedObject var selectImage = MarkupEditor.selectImage
    @State private var rawText = NSAttributedString(string: "")
    @State private var documentPickerShowing: Bool = false
    @State private var rawShowing: Bool = false
    @State private var demoHtml: String
    
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
        markupConfiguration.userCssFile = "spaDemo.css"
        markupConfiguration.userScriptFile = "spaDemo.js"
        _demoHtml = State(initialValue: "")
        initDivStructure()
    }
    
    private func initDivStructure() {
        let documentDivs: [MarkupDiv] = [
            Div1(name: "Chapter 1 - It Begins"),
            Div2(id: "Section1", name: "We Have Liftoff"),
            Div3(contents: "<p>This is an editable subsection</p>"),
            Div3(contents: "<p>This is also an editable subsection</p>"),
            Div2(id: "Section2", name: "Epilogue"),
            Div3(contents: "<p>The demo is over</p>"),
        ]
        
        for div in documentDivs {
            divStructure.add(div)
            // For Div2's, which are kind Section separators, we want buttons
            if div is Div2 {
                divStructure.add([
                    MarkupButton(label: "􀋭", action: { inspect(div.id) }),
                    MarkupButton(label: "􀈑", action: { delete(div.id) }),
                ], in: div.id)
            }
        }
    }
    
    private func setRawText(_ handler: (()->Void)? = nil) {
        MarkupEditor.selectedWebView?.getHtml(clean: false) { html in
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
    
    private func delete(_ element: String) {
        print("Delete element: \(element)")
    }
    
    private func inspect(_ element: String) {
        print("Inspect element: \(element)")
    }
    
}

extension SpaContentView: MarkupDelegate {
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        
        MarkupEditor.selectedWebView = view
        for div in divStructure.divs {
            view.addDiv(div)
            if let buttonGroup = div.buttonGroup {
                for button in buttonGroup.buttons {
                    view.addButton(button, in: buttonGroup.id)
                }
            }
        }
        for buttonGroup in divStructure.buttonGroups {
            view.addDiv(buttonGroup)
            for button in buttonGroup.buttons {
                view.addButton(button, in: buttonGroup.id)
            }
        }
        setRawText(handler)
    }
    
    func markupClicked(_ view: MarkupWKWebView) {
        view.getSelectionState { state in
            print("Selected div ID: \(state.divid ?? "nil")")
        }
    }
    
    func markupButtonClicked(_ view: MarkupWKWebView, id: String, rect: CGRect) {
        print("Button \(id) at \(rect) was clicked.")
        if let action = divStructure.action(for: id) {
            action()
        }
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

extension SpaContentView: FileToolbarDelegate {

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

extension String {
    var unicodeName: String {
        let cfstr = NSMutableString(string: self) as CFMutableString
        var range = CFRangeMake(0, CFStringGetLength(cfstr))
        CFStringTransform(cfstr, &range, kCFStringTransformToUnicodeName, false)
        return String(cfstr)
    }
}
