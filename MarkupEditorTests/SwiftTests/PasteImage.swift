//
//  PasteImage.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/14/25.
//

import MarkupEditor
import Testing
import UIKit

/// This test ensures that when an image is pasted into a document in the Swift MarkupEditor, the image src points at a UUID string
/// name that was exists in the document directory. The test is Swift MarkupEditor specific. This functionality is not available in
/// markupeditor-base. In the markupeditor-desktop app, a roughly analogous approach is used wherein the data for the image is
/// embedded in the src, and that data is saved into a file in the document directory at save time for the document.
@Suite
class PasteImage: MarkupDelegate {
    var webView: MarkupWKWebView!
    var coordinator: MarkupCoordinator!
    var htmlTest: HtmlTest!
    var action: ((MarkupWKWebView) async throws -> String?)!
    var continuation: CheckedContinuation<Bool, Never>?
    var imageLoadedContinuation: CheckedContinuation<Bool, Never>?

    /// Once-per test initialization, which is frankly ridiculous, but there is no way to do a once-per-suite initialization
    init() async throws {
        _ = await withCheckedContinuation { continuation in
            self.continuation = continuation
            webView = MarkupWKWebView(markupDelegate: self)
            coordinator = MarkupCoordinator(markupDelegate: self, webView: webView)
            webView.setCoordinatorConfiguration(coordinator)
            htmlTest = HtmlTest(
                description: "Image in P - Paste image at insertion point in a word",
                skipUndoRedo: true, // TODO: Won't work with the flow of HtmlTest.run
                startHtml: "<p>This is ju|st a simple paragraph.</p>"
            )
            action = paste
        }
    }
    
    deinit {
        webView = nil
        coordinator = nil
        htmlTest = nil
    }
    
    /// Paste a UIImage at the selection point. Paste is handled on the Swift side, where the clipboard contents
    /// produces a UIImage, and then the image contents is saved to a unique filename in the document directory.
    /// The filename is then passed to the JavaScript side as src pointing at the local filename. The name is
    /// uniquely generated, so the test just makes sure it is in an expected form and actually exists. When we
    /// paste an image this way, we have to wait for the MarkupDelegate markupImageAdded callback, because
    /// the addition of image size is done async based on the actual image size.
    func paste(webview: MarkupWKWebView) async throws -> String? {
        await webview.pasteImage(UIImage(systemName: "calendar"))
        _ = await withCheckedContinuation { continuation in
            self.imageLoadedContinuation = continuation
            webview.getTestHtml(sel: "|") { html in
                if let imageFileName = self.imageFilename(in: html) {
                    #expect(webview.resourceExists(imageFileName))
                } else {
                    #expect(Bool(false))
                }
                // For undo/redo to work, we need to reassign, but this makes HtmlTest non-sendable
                //self.htmlTest.endHtml = html ?? self.htmlTest.startHtml
            }
        }
        return htmlTest.endHtml
    }

    /// Since we marked self as the `markupDelegate`, we receive the `markupDidLoad` message
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        continuation?.resume(returning: true)
        continuation = nil
    }

    func markupImageAdded(url: URL) {
        imageLoadedContinuation?.resume(returning: true)
        imageLoadedContinuation = nil
    }
    
    func imageFilename(in tag: String?) -> String? {
        // The tag must be a valid <img> tag, like <img src="2537ACEF-A318-4395-8955-8F2C73701AD0.png">
        guard
            let tag,
            tag.contains("<img"),
            let srcRange = tag.range(of: "src=\"") else {
            return nil
        }
        let srcSize = UUID().uuidString.count + 4    // The image file name will always be a UUID + extension
        let startIndex = srcRange.upperBound
        let endIndex = tag.index(startIndex, offsetBy: srcSize)
        return String(tag[startIndex..<endIndex])
    }

    /// Run the HtmlTest
    @Test(.timeLimit(.minutes(HtmlTest.timeLimit)), )
    func run() async throws {
        try await htmlTest.run(action: action, in: webView)
    }

}
