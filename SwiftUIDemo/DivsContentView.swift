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
        markupConfiguration.topLevelAttributes = EditableAttributes.standard
        markupConfiguration.userCssFile = "demoDivs.css"
        _demoHtml = State(initialValue: "")
        initDivStructure()
    }
    
    /// Create the DivStructure that holds the array of HtmlDivs in the document we are editing.
    private func initDivStructure() {
        divStructure.add(
            TitleDiv(contents: "Multi-Div Editing")
        )
        divStructure.add(
            SectionDiv(
                contents: "Multiple Editable Areas"
            )
        )
        divStructure.add(
            ContentDiv(htmlContents: "<p>The document consists of several sections. Think of each section as representing a model object in your application. Each section has a header to delineate it. The header itself is not editable, but you can still select it. When you select the header or the content below it, the <code>markupClicked</code> callback is invoked. We can identify the id of the div that was clicked-in based on the <code>selectionState</code>. From the div id, we can use <code>divStructure</code> to identify the section, and based on the section, we can add buttons to the header that let us perform operations on that section or the model object it represents.</p>"
            )
        )
        divStructure.add(
            SectionDiv(
                focusId: "HtmlDiv",
                contents: "HtmlDiv",
                buttons: [
                    // We should be able to use SFSymbols here (e.g., 􀈑 and 􀋭), but they went missing.
                    // See https://feedbackassistant.apple.com/feedback/13537558.
                    // For now, fill in with Emojis.
                    HtmlButton(label: "🧐", targetId: "HtmlDiv", action: { actionInfo in inspect(actionInfo) }),
                    HtmlButton(label: "🗑️", targetId: "HtmlDiv", action: { actionInfo in delete(actionInfo) }),
                ]
            )
        )
        divStructure.add(
            ContentDiv(
                id: "HtmlDiv",
                htmlContents: "<p>An <code>HtmlDiv</code> is a Swift class that represents an <a href=\"https://developer.mozilla.org/en-US/docs/Web/HTML/Element/div\">HTML Content Division Element</a> or &lt;div&gt; that we insert into the document.</p><p>Every HtmlDiv needs a unique ID, since it will ultimately be placed in an HTML DOM as a &lt;div&gt; with that ID.</p><p>For each kind of HtmlDiv you are going to use, you should create a Swift class or struct that conforms to HtmlDivHolder. In this example, we use a single TitleDiv, and multiple pairs of SectionDiv and ContentDiv. Each one holds an HtmlDiv that specifies the ID and other properties of the div itself. Your HtmlDivHolder class/struct provides the behavior and state on the Swift side to make it simpler to instantiate and otherwise use in the context of your app. So, for example, to instantiate a TitleDiv, we simply have to pass a string. The TitleDiv itself creates the HtmlDiv with a cssClass of <code>title</code> that lets us control the styling of the title.</p><p>Besides its own <code>id</code>, an HtmlDiv can hold onto three other IDs:</p><ul><li><p><code>parentId</code>: The ID of the HtmlDiv that this HtmlDiv should be a child of.</p></li><li><p><code>targetId</code>: An ID that can be used to dereference a Swift object from this HtmlDiv.</p></li><li><p><code>focusId</code>: An ID that can be used to identify an HtmlDiv that should take focus when this HtmlDiv is clicked.</p></li></ul>"
            )
        )
        divStructure.add(
            SectionDiv(
                focusId: "Buttons",
                contents: "Buttons",
                buttons: [
                    // We should be able to use SFSymbols here (e.g., 􀈑 and 􀋭), but they went missing.
                    // See https://feedbackassistant.apple.com/feedback/13537558.
                    // For now, fill in with Emojis.
                    HtmlButton(label: "🧐", targetId: "Buttons", action: { actionInfo in inspect(actionInfo) }),
                    HtmlButton(label: "🗑️", targetId: "Buttons", action: { actionInfo in delete(actionInfo) }),
                ],
                dynamic: true
            )
        )
        divStructure.add(
            ContentDiv(
                id: "Buttons",
                htmlContents: "<p>A div like the SectionDiv defined in this demo can contain buttons, and those buttons can be always shown or dynamically added when the target gets focus.</p>")
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
    
    private func buttonGroup(forFocusId focusId: String?) -> HtmlButtonGroup? {
        guard let focusId else { return nil }
        if let buttonGroupId = divStructure.buttonGroupId(forDivId: focusId) {
            return divStructure.div(forDivId: buttonGroupId) as? HtmlButtonGroup
        } else {
            return nil
        }
    }
    
    private func addButtons(focusId: String?, view: MarkupWKWebView, handler: (() -> Void)? = nil) {
        if let buttonGroup = buttonGroup(forFocusId: focusId), buttonGroup.isDynamic {
            view.addButtonGroup(buttonGroup, handler: handler)
        } else {
            handler?()
        }
    }
    
    private func removeButtons(focusId: String?, view: MarkupWKWebView, handler: (() -> Void)? = nil) {
        if let buttonGroup = buttonGroup(forFocusId: focusId), buttonGroup.isDynamic {
            view.removeButtonGroup(buttonGroup, handler: handler)
        } else {
            handler?()
        }
    }
    
    private func resetDivs(handler: (()->Void)? = nil) {
        guard let view = MarkupEditor.selectedWebView else {
            handler?()
            return
        }
        view.removeAllDivs() {
            view.load(divStructure: divStructure) {
                setRawText() {
                    handler?()
                }
            }
        }
    }
    
}

extension DivsContentView: MarkupDelegate {
    
    /// The MarkupWKWebView is ready. Use the divStructure to add all the divs.
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        MarkupEditor.selectedWebView = view
        resetDivs(handler: handler)
        // Only set the placeholder after the divs are set; otherwise, it will flash briefly
        // before they show up because the initial content is empty. Not setting a placeholder
        // is fine, too, of course. It's only relevant in this demo because it includes the
        // FileToolbar, which can clear the entire document.
        view.setPlaceholder(text: "Add document content...")
    }
    
    /// The user clicked/touched in some div, whether it's contenteditable or not.
    ///
    /// Since we are using "dynamic" buttons (i.e., ones that we only want to show when a section is selected),
    /// we need to take action to add and remove buttons based on the new selection state. The `state.divid`
    /// gives us the `id` of the div that is selected. Based on the `id`, we can determine the actual `HtmlDiv` by
    /// querying the `divStructure` of the document. By design, we identified a `focusId` for the `SectionDiv`,
    /// so we can focus on the `ContentDiv` when selecting the `SectionDiv` or in the `MarkupButtonGroup` it
    /// holds. We can also use the `focusId` to identify the `MarkupButtonGroup`, and then we can add and remove
    /// that `MarkupButtonGroup` in the view we get here. The `MarkupButtonGroup` knows what div it belongs in,
    /// because its `parentId` was established when we created it.
    func markupClicked(_ view: MarkupWKWebView) {
        let oldFocusId = selectedDivID
        view.getSelectionState { state in
            if let divId = state.divid, let div = divStructure.div(forDivId: divId) {
                if let focusId = div.focusId {  // We selected a div that indicates another div to focus on
                    if focusId != oldFocusId {
                        removeButtons(focusId: oldFocusId, view: view)
                        addButtons(focusId: focusId, view: view)
                        view.focus(on: focusId)
                        selectedDivID = focusId
                    }   // Else do nothing
                } else if state.isValid { // We selected a ContentDiv, so it will be focused already
                    if divId != oldFocusId {
                        removeButtons(focusId: oldFocusId, view: view)
                        selectedDivID = divId
                        addButtons(focusId: divId, view: view)
                    }   // Else do nothing
                } else {
                    removeButtons(focusId: oldFocusId, view: view)
                    selectedDivID = nil
                }
            } else {
                removeButtons(focusId: oldFocusId, view: view)
                selectedDivID = nil
            }
            setRawText()
        }
    }
    
    func markupButtonClicked(_ view: MarkupWKWebView, id: String, rect: CGRect) {
        print("Button \(id) at \(rect) was clicked.")
        if let button = divStructure.button(forButtonId: id) {
            button.executeAction(view: view, rect: rect)
        }
    }
    
    func markupInput(_ view: MarkupWKWebView, divId: String) {
        if let div = divStructure.div(forDivId: divId) {
            print("Input from div \(div.id).")
        }
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

extension DivsContentView: FileToolbarDelegate {

    func newDocument(handler: ((URL?)->Void)? = nil) {
        // For the DivsContentView, it's useful to add a new empty div so we can see how that works.
        
        MarkupEditor.selectedWebView?.emptyDocument() {
            selectedDivID = nil
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
