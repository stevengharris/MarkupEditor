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
        _demoHtml = State(initialValue: "")
        initDivStructure()
    }
    
    /// Create the DivStructure that holds the array of HtmlDivs in the document we are editing.
    private func initDivStructure() {
        divStructure.add(TitleDiv(name: "Multi-Div Editing")
        )
        divStructure.add(SectionDiv(
            name: "Multiple Editable Areas",
            buttons: [
                // We should be able to use SFSymbols here (e.g., 􀈑 and 􀋭), but they went missing.
                // See https://feedbackassistant.apple.com/feedback/13537558.
                // For now, fill in with Emojis.
                HtmlButton(label: "🧐", targetId: "Section1", action: { actionInfo in inspect(actionInfo) }),
                HtmlButton(label: "🗑️", targetId: "Section1", action: { actionInfo in delete(actionInfo) }),
            ])
        )
        divStructure.add(ContentDiv(contents: "<p>The document consists of several sections. Think of each section as representing a model object in your application. Each section has a header to delineate it. The header itself is not editable, but you can still select it. When you select the header or the content below it, the <code>markupClicked</code> callback is invoked. We can identify the id of the div that was clicked-in based on the <code>selectionState</code>. From the div id, we can use <code>divStructure</code> to identify the section, and based on the section, we can add buttons to the header that let us perform operations on that section or the model object it represents.</p>")
        )
        divStructure.add(SectionDiv(
            name: "HtmlDiv",
            buttons: [
                // We should be able to use SFSymbols here (e.g., 􀈑 and 􀋭), but they went missing.
                // See https://feedbackassistant.apple.com/feedback/13537558.
                // For now, fill in with Emojis.
                HtmlButton(label: "🧐", targetId: "Section2", action: { actionInfo in inspect(actionInfo) }),
                HtmlButton(label: "🗑️", targetId: "Section2", action: { actionInfo in delete(actionInfo) }),
            ])
        )
        divStructure.add(ContentDiv(contents: "<p>An <code>HtmlDiv</code> is a Swift class that represents an <a href=\"https://developer.mozilla.org/en-US/docs/Web/HTML/Element/div\">HTML Content Division Element</a> or &lt;div&gt; that we insert into the document.</p><p>Every HtmlDiv needs a unique ID, since it will ultimately be placed in an HTML DOM as a &lt;div&gt; with that ID.</p><p>For each kind of HtmlDiv you are going to use, you should create a Swift class or struct that conforms to HtmlDivHolder. In this example, we use a single TitleDiv, and multiple pairs of SectionDiv and ContentDiv. Each one holds an HtmlDiv that specifies the ID and other properties of the div itself. Your HtmlDivHolder class/struct provides the behavior and state on the Swift side to make it simpler to instantiate and otherwise use in the context of your app. So, for example, to instantiate a TitleDiv, we simply have to pass a string. The TitleDiv itself creates the HtmlDiv with a cssClass of <code>title</code> that lets us control the styling of the title.</p><p>Besides its own <code>id</code>, an HtmlDiv can hold onto three other IDs:</p><ul><li><p><code>parentId</code>: The ID of the HtmlDiv that this HtmlDiv should be a child of.</p></li><li><p><code>targetId</code>: An ID that can be used to dereference a Swift object from this HtmlDiv.</p></li><li><p><code>focusId</code>: An ID that can be used to identify an HtmlDiv that should take focus when this HtmlDiv is clicked.</p></li></ul>")
        )
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
