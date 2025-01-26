//
//  MarkupEditorTests.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 3/5/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import XCTest
// import SharedTest    <- Needed for "swift test" but breaks "xcodebuild test"
import MarkupEditor
import OSLog

class BasicTests: XCTestCase, MarkupDelegate {
    var webView: MarkupWKWebView!
    var coordinator: MarkupCoordinator!
    var loadedExpectation: XCTestExpectation = XCTestExpectation(description: "Loaded")
    var undoSetHandler: (()->Void)?
    var inputHandler: (()->Void)?
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        webView = MarkupWKWebView(markupDelegate: self)
        coordinator = MarkupCoordinator(markupDelegate: self, webView: webView)
        // The coordinator will receive callbacks from markup.js
        // using window.webkit.messageHandlers.test.postMessage(<message>);
        webView.configuration.userContentController.add(coordinator, name: "markup")
        // Not sure what happened with XCTest, but somewhere along Xcode upgrades this initial
        // loading *in testing only, not in real life usage* takes a very long time.
        wait(for: [loadedExpectation], timeout: 30)
    }
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        // Since we marked self as the markupDelegate, we receive the markupDidLoad message
        loadedExpectation.fulfill()
        handler?()
    }
    
    /// Execute the inputHandler once if defined, then nil it out
    func markupInput(_ view: MarkupWKWebView) {
        guard let inputHandler = inputHandler else {
            return
        }
        //print("*** handling input")
        inputHandler()
        self.inputHandler = nil
    }
    
    /// Use the inputHandlers in order, removing them as we use them
    func markupUndoSet(_ view: MarkupWKWebView) {
        guard let undoSetHandler = undoSetHandler else {
            return
        }
        //print("*** handling undoSet")
        undoSetHandler()
        self.undoSetHandler = nil
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func assertEqualStrings(expected: String, saw: String?) {
        XCTAssert(expected == saw, "Expected \(expected), saw: \(saw ?? "nil")")
    }
    
    func addInputHandler(_ handler: @escaping (()->Void)) {
        inputHandler = handler
    }
    
    func addUndoSetHandler(_ handler: @escaping (()->Void)) {
        undoSetHandler = handler
    }
    
    func withoutSelection(_ html: String) -> String {
        return html.replacingOccurrences(of: "|", with: "")
    }
    
    func testLoad() throws {
        Logger.test.info("Test: Ensure loadInitialHtml has run.")
        // Do nothing other than run setupWithError
    }
    
    func testBaselineBehavior() throws {
        Logger.test.info("Test: Ensure setting contents, selection, and text extraction work as expected.")
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Extract when selection begins in one styled list item, ends in another",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P |Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P |Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testExtractContents {
                            handler()
                        }
                    }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: test.description ?? "Basic operations")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    // Execute the action to press Enter at the selection
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testFormats() throws {
        // Inline comments show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Bold selection",
                    startHtml: "<p>This |is| a start</p>",
                    endHtml: "<p>This <strong>is</strong> a start</p>"
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Italic selection",
                    startHtml: "<p>This |is| a start</p>",
                    endHtml: "<p>This <em>is</em> a start</p>"
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Underline selection",
                    startHtml: "<p>This |is| a start</p>",
                    endHtml: "<p>This <u>is</u> a start</p>"
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Strikethrough selection",
                    startHtml: "<p>This |is| a start</p>",
                    endHtml: "<p>This <s>is</s> a start</p>"
                ),
                { handler in
                    self.webView.strike() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Superscript selection",
                    startHtml: "<p>This |is| a start</p>",
                    endHtml: "<p>This <sup>is</sup> a start</p>"
                ),
                { handler in
                    self.webView.superscript() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Subscript selection",
                    startHtml: "<p>This |is| a start</p>",
                    endHtml: "<p>This <sub>is</sub> a start</p>"
                ),
                { handler in
                    self.webView.subscriptText() { handler() }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Format selection")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    // Execute the action to format the selection
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testUnformats() throws {
        // Inline comments show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Inside bold selection",
                    startHtml: "<p>This <strong>|is|</strong> a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outside bold selection",
                    startHtml: "<p>This |<strong>is</strong>| a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Inside italic selection",
                    startHtml: "<p>This <em>|is|</em> a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outisde italic selection",
                    startHtml: "<p>This |<em>is</em>| a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Inside underline selection",
                    startHtml: "<p>This <u>|is|</u> a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outside underline selection",
                    startHtml: "<p>This |<u>is</u>| a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Inside strikethrough selection",
                    startHtml: "<p>This <s>|is|</s> a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.strike() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outside strikethrough selection",
                    startHtml: "<p>This |<s>is</s>| a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.strike() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Inside superscript selection",
                    startHtml: "<p>This <sup>|is|</sup> a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.superscript() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outside superscript selection",
                    startHtml: "<p>This |<sup>is</sup>| a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.superscript() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Inside subscript selection",
                    startHtml: "<p>This <sub>|is|</sub> a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.subscriptText() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outside subscript selection",
                    startHtml: "<p>This |<sub>is</sub>| a start</p>",
                    endHtml: "<p>This is a start</p>"
                ),
                { handler in
                    self.webView.subscriptText() { handler() }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Unformat selection")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    // Execute the action to unformat the selection
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testFormatSelections() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Bold selection",
                    startHtml: "<p>This <strong>i|s</strong> a start</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.bold)
                        handler()
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Italic selection",
                    startHtml: "<p>This <em>i|s</em> a start</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.italic)
                        handler()
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Underline selection",
                    startHtml: "<p>This <u>i|s</u> a start</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.underline)
                        handler()
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Strikethrough selection",
                    startHtml: "<p>This <s>i|s</s> a start</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.strike)
                        handler()
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Superscript selection",
                    startHtml: "<p>This <sup>i|s</sup> a start</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.sup)
                        handler()
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Subscript selection",
                    startHtml: "<p>This <sub>i|s</sub> a start</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.sub)
                        handler()
                    }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Format selection")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    // Execute the action to determine the format of the selection
                    action() {
                        expectation.fulfill()
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testMultiFormats() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Unbold <p><strong><u>Wo|rd 1 Word 2 Wo|rd 3</u></strong></p>",
                    startHtml: "<p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
                    endHtml: "<p><u><strong>Wo</strong>rd 1 Word 2 Wo<strong>rd 3</strong></u></p>"
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Underline <p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
                    startHtml: "<p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
                    endHtml: "<p><u><strong>Wo</strong></u><strong>rd 1 Word 2 Wo</strong><u><strong>rd 3</strong></u></p>"
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Italic <p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
                    startHtml: "<p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
                    endHtml: "<p><u><strong>Wo</strong></u><em><u><strong>rd 1 Word 2 Wo</strong></u></em><u><strong>rd 3</strong></u></p>"
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Bold <p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                    startHtml: "<p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                    endHtml: "<p><strong>Hello </strong><u><strong>bold </strong>and<strong> underline</strong></u><strong> world</strong></p>"
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Underline <p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                    startHtml: "<p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                    endHtml: "<p><strong>Hello </strong><u><strong>bold </strong></u><strong>and</strong><u><strong> underline</strong></u><strong> world</strong></p>"
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Italic <p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                    startHtml: "<p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                    endHtml: "<p><strong>Hello </strong><u><strong>bold </strong></u><em><u><strong>and</strong></u></em><u><strong> underline</strong></u><strong> world</strong></p>"
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Bold <p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                    startHtml: "<p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                    endHtml: "<p><em>Hello </em>wo<strong>rld</strong></p>"
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Underline <p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                    startHtml: "<p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                    endHtml: "<p><em><u><strong>Hello </strong></u></em><u><strong>wo</strong></u><strong>rld</strong></p>"
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Italic <p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                    startHtml: "<p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                    endHtml: "<p><strong>Hello world</strong></p>"
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Bold <p>|Hello <em>world|</em></p>",
                    startHtml: "<p>|Hello <em>world|</em></p>",
                    endHtml: "<p><strong>Hello </strong><em><strong>world</strong></em></p>"
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Underline <p>|Hello <em>world|</em></p>",
                    startHtml: "<p>|Hello <em>world|</em></p>",
                    endHtml: "<p><u>Hello </u><em><u>world</u></em></p>"
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Italic <p>|Hello <em>world|</em></p>",
                    startHtml: "<p>|Hello <em>world|</em></p>",
                    endHtml: "<p>Hello world</p>"
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Bold <p><u><strong>He|llo wo|rld</strong></u></p>",
                    startHtml: "<p><u><strong>He|llo wo|rld</strong></u></p>",
                    endHtml: "<p><u><strong>He</strong>llo wo<strong>rld</strong></u></p>"
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Underline <p><u><strong>He|llo wo|rld</strong></u></p>",
                    startHtml: "<p><u><strong>He|llo wo|rld</strong></u></p>",
                    endHtml: "<p><u><strong>He</strong></u><strong>llo wo</strong><u><strong>rld</strong></u></p>"
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Italic <p><u><strong>He|llo wo|rld</strong></u></p>",
                    startHtml: "<p><u><strong>He|llo wo|rld</strong></u></p>",
                    endHtml: "<p><u><strong>He</strong></u><em><u><strong>llo wo</strong></u></em><u><strong>rld</strong></u></p>"
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Bold across partial paragraphs <p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                    startHtml: "<p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                    endHtml: "<p>Hello <em>world</em></p><p>Hello <em>wo<strong>rld</strong></em></p>"
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Underline across partial paragraphs <p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                    startHtml: "<p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                    endHtml: "<p><u>Hello </u><em><u>world</u></em></p><p><u><strong>Hello </strong></u><em><u><strong>wo</strong></u><strong>rld</strong></em></p>"
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Italic across partial paragraphs <p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                    startHtml: "<p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                    endHtml: "<p>Hello world</p><p><strong>Hello wo</strong><em><strong>rld</strong></em></p>"
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Bold across all-bolded paragraphs <p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                    startHtml: "<p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                    endHtml: "<p>Hello <em>world</em></p><p>Hello <em>world</em></p>"
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Underline across all-bolded paragraphs <p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                    startHtml: "<p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                    endHtml: "<p><u><strong>Hello </strong></u><em><u><strong>world</strong></u></em></p><p><u><strong>Hello </strong></u><em><u><strong>world</strong></u></em></p>"
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Italic across all-bolded paragraphs <p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                    startHtml: "<p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                    endHtml: "<p><strong>Hello world</strong></p><p><strong>Hello world</strong></p>"
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "UnsetAll italic across paragraphs <p>This <em>is| italic</em></p><p><em>Ex|tending across</em> paragraphs</p>",
                    startHtml: "<p>This <em>is| italic</em></p><p><em>Ex|tending across</em> paragraphs</p>",
                    endHtml: "<p>This <em>is</em> italic</p><p>Ex<em>tending across</em> paragraphs</p>"
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Unformatting nested tags")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    // Execute the action to format across the selection
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testStyles() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Replace p with h1",
                    startHtml: "<p><em><strong>He|llo </strong></em><strong>world</strong></p>",
                    endHtml: "<h1><em><strong>Hello </strong></em><strong>world</strong></h1>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Replace h2 with h6",
                    startHtml: "<h2>|Hello worl|d</h2>",
                    endHtml: "<h6>Hello world</h6>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H6) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Replace h3 with p",
                    startHtml: "<h3>He|llo wor|ld</h3>",
                    endHtml: "<p>Hello world</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .P) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Setting and replacing styles")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    // Execute the action to style at the selection
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testMultiStyles() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Replace p with h1, selection in embedded format",
                    startHtml: "<p><em><strong>He|llo </strong></em><strong>world1</strong></p><p><em><strong>Hello </strong></em><strong>world2</strong></p><p><em><strong>He|llo </strong></em><strong>world3</strong></p>",
                    endHtml: "<h1><em><strong>Hello </strong></em><strong>world1</strong></h1><h1><em><strong>Hello </strong></em><strong>world2</strong></h1><h1><em><strong>Hello </strong></em><strong>world3</strong></h1>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Replace p with h1, selection outside embedded format both ends",
                    startHtml: "<p><em><strong>|Hello </strong></em><strong>world1</strong></p><p><em><strong>Hello </strong></em><strong>world2</strong></p><p><em><strong>Hello </strong></em><strong>world3|</strong></p>",
                    endHtml: "<h1><em><strong>Hello </strong></em><strong>world1</strong></h1><h1><em><strong>Hello </strong></em><strong>world2</strong></h1><h1><em><strong>Hello </strong></em><strong>world3</strong></h1>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Replace p with h1, selection outside embedded format at start",
                    startHtml: "<p><em><strong>|Hello </strong></em><strong>world1</strong></p><p><em><strong>Hello </strong></em><strong>world2</strong></p><p><em><strong>Hello </strong></em><strong>wo|rld3</strong></p>",
                    endHtml: "<h1><em><strong>Hello </strong></em><strong>world1</strong></h1><h1><em><strong>Hello </strong></em><strong>world2</strong></h1><h1><em><strong>Hello </strong></em><strong>world3</strong></h1>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Replace p with h1, selection across indented paragraphs",
                    startHtml: "<blockquote><p>Pa|ragraph 1</p></blockquote><blockquote><p>Paragraph 2</p></blockquote><blockquote><p>Pa|ragraph 3</p></blockquote>",
                    endHtml: "<blockquote><h1>Paragraph 1</h1></blockquote><blockquote><h1>Paragraph 2</h1></blockquote><blockquote><h1>Paragraph 3</h1></blockquote>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Setting and replacing styles across multiple paragraphs")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    // Execute the action to style across the selection
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }

    func testDenting() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Indent, selection in text element",
                    startHtml: "<p>He|llo <strong>world</strong></p>",
                    endHtml: "<blockquote><p>Hello <strong>world</strong></p></blockquote>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Indent, selection in a formatted element",
                    startHtml: "<p><em><strong>He|llo </strong></em><strong>world</strong></p>",
                    endHtml: "<blockquote><p><em><strong>Hello </strong></em><strong>world</strong></p></blockquote>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outdent from 1 to 0, selection in nested format",
                    startHtml: "<blockquote><p><em><strong>He|llo </strong></em><strong>world</strong></p></blockquote>",
                    endHtml: "<p><em><strong>Hello </strong></em><strong>world</strong></p>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outdent from 2 to 1, selection in nested format",
                    startHtml: "<blockquote><blockquote><p><em><strong>He|llo </strong></em><strong>world</strong></p></blockquote></blockquote>",
                    endHtml: "<blockquote><p><em><strong>Hello </strong></em><strong>world</strong></p></blockquote>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Indent in an embedded paragraph in a blockquote, selection in a non-text element",
                    startHtml: "<blockquote><p><em><strong>Hello </strong></em><strong>world</strong></p><p><em><strong>He|llo </strong></em><strong>world</strong></p></blockquote>",
                    endHtml: "<blockquote><p><em><strong>Hello </strong></em><strong>world</strong></p><blockquote><p><em><strong>Hello </strong></em><strong>world</strong></p></blockquote></blockquote>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Increasing and decreasing block levels")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    // Execute the action to indent/outdent at the selection
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testMultiDenting() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Indent <p>He|llo world1</p><p>He|llo world2</p>",
                    startHtml: "<p>He|llo world1</p><p>He|llo world2</p>",
                    endHtml: "<blockquote><p>Hello world1</p><p>Hello world2</p></blockquote>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outdent no-op <blockquote><p>He|llo world1</p></blockquote><blockquote><p>He|llo world2</p></blockquote>",
                    startHtml: "<blockquote><p>He|llo world1</p></blockquote><blockquote><p>He|llo world2</p></blockquote>",
                    endHtml: "<blockquote><p>Hello world1</p></blockquote><blockquote><p>Hello world2</p></blockquote>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Indent <p>He|llo world1</p><h5>He|llo world2</h5>",
                    startHtml: "<p>He|llo world1</p><h5>He|llo world2</h5>",
                    endHtml: "<blockquote><p>Hello world1</p><h5>Hello world2</h5></blockquote>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outdent no-op <blockquote><p>He|llo world1</p></blockquote><blockquote><h5>He|llo world2</h5></blockquote>",
                    startHtml: "<blockquote><p>He|llo world1</p></blockquote><blockquote><h5>He|llo world2</h5></blockquote>",
                    endHtml: "<blockquote><p>Hello world1</p></blockquote><blockquote><h5>Hello world2</h5></blockquote>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Indent <p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                    startHtml: "<p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                    endHtml: "<blockquote><p>Hello paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></blockquote>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outdent no-op <blockquote><p>He|llo paragraph</p></blockquote><ul><li><h5>He|llo header in list</h5></li></ul>",
                    startHtml: "<blockquote><p>He|llo paragraph</p></blockquote><ul><li><h5>He|llo header in list</h5></li></ul>",
                    endHtml: "<blockquote><p>Hello paragraph</p></blockquote><ul><li><h5>Hello header in list</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Indent no-op <ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.</p></li></ol></li></ul>",
                    startHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.</p></li></ol></li></ul>",
                    endHtml: "<ul><li><h5>Unordered <em>H5</em> list.</h5><ol><li><p>Ordered sublist.</p></li></ol></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outdent <ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.<p></li></ol></li></ul>",
                    startHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.</p></li></ol></li></ul>",
                    endHtml: "<h5>Unordered <em>H5</em> list.</h5><ol><li><p>Ordered sublist.</p></li></ol>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Indent interleaved paragraphs and lists",
                    startHtml: "<p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol>",
                    endHtml: "<blockquote><p>Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>Top-level paragraph 2</p></blockquote><ol><li><p>Ordered list paragraph 1</p></li></ol>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outdent no-op interleaved paragraphs and lists",
                    startHtml: "<p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol>",
                    endHtml: "<p>Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>Top-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Indent no-op list with sublists",
                    startHtml: "<ul><li><h5>Un|ordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>Wi|th two items.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Unordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>With two items.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outdent no-op list with sublists",
                    startHtml: "<ul><li><h5>Un|ordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>Wi|th two items.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Unordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>With two items.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outdent no-op, start and end in styles surround list",
                    startHtml: "<p>St|arting paragraph.</p><ul><li><h5>Unordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>With two items.</h5></li></ul><p>En|ding paragraph.</p>",
                    endHtml: "<p>Starting paragraph.</p><ul><li><h5>Unordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>With two items.</h5></li></ul><p>Ending paragraph.</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Indent/outdent operations with selections spanning multiple elements")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    // Execute the action to indent/outdent at the selection
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testBlockquoteEnter() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest.withSelection(
                description: "Enter at beginning of simple paragraph in blockquote",
                startHtml: "<blockquote><p>|This is a simple paragraph</p></blockquote>",
                endHtml: "<blockquote><p><br></p></blockquote><blockquote><p>This is a simple paragraph</p></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Enter in middle of simple paragraph in blockquote",
                startHtml: "<blockquote><p>This is a sim|ple paragraph</p></blockquote>",
                endHtml: "<blockquote><p>This is a sim</p></blockquote><blockquote><p>ple paragraph</p></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Enter at end of simple paragraph in blockquote",
                startHtml: "<blockquote><p>This is a simple paragraph|</p></blockquote>",
                endHtml: "<blockquote><p>This is a simple paragraph</p></blockquote><blockquote><p><br></p></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Enter at beginning of simple paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p>|This is a simple paragraph</p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p><br></p></blockquote><blockquote><p>This is a simple paragraph</p></blockquote></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Enter in middle of simple paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p>This is a sim|ple paragraph</p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p>This is a sim</p></blockquote><blockquote><p>ple paragraph</p></blockquote></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Enter at end of simple paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p>This is a simple paragraph|</p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p>This is a simple paragraph</p></blockquote><blockquote><p><br></p></blockquote></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Enter at end of empty paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p>This is a simple paragraph|</p></blockquote><blockquote><p><br></p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p>This is a simple paragraph</p></blockquote><blockquote><p><br></p></blockquote><blockquote><p><br></p></blockquote></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Outdent on enter at end of empty paragraph in unnested blockquotes",
                startHtml: "<blockquote><p>This is a simple paragraph</p></blockquote><blockquote><p>|</p></blockquote>",
                endHtml: "<blockquote><p>This is a simple paragraph</p></blockquote><p><br></p>"
            ),
            // We don't wait for images to load or fail, so we specify the class, tabindex, width, and height on
            // input so we get the same thing back.
            HtmlTest.withSelection(
                description: "Enter before image in blockquote",
                startHtml: "<blockquote><p>|<img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>",
                endHtml: "<blockquote><p><br></p></blockquote><blockquote><p><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Enter after image in blockquote",
                startHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\">|</p></blockquote>",
                endHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote><blockquote><p><br></p></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Enter between images in blockquote",
                startHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\">|<img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>",
                endHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote><blockquote><p><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Enter between text and image in blockquote",
                startHtml: "<blockquote><p>Hello|<img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>",
                endHtml: "<blockquote><p>Hello</p></blockquote><blockquote><p><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Enter between image and text in blockquote",
                startHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\">|Hello</p></blockquote>",
                endHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote><blockquote><p>Hello</p></blockquote>"
            ),
            HtmlTest.withSelection(
                description: "Enter at end of text in formatted element",
                startHtml: "<blockquote><p><strong>Hello|</strong></p></blockquote>",
                endHtml: "<blockquote><p><strong>Hello</strong></p></blockquote><blockquote><p><strong><br></strong></p></blockquote>"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Enter being pressed inside of blockquotes")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    self.addInputHandler {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                    // Kick off the enter operation in the blockquote we selected
                    self.webView.testBlockquoteEnter()
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }

    func testLists() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Make a paragraph into an ordered list",
                    startHtml: "<p>He|llo <strong>world</strong></p>",
                    endHtml: "<ol><li><p>Hello <strong>world</strong></p></li></ol>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Make a paragraph into an unordered list",
                    startHtml: "<p>He|llo <strong>world</strong></p>",
                    endHtml: "<ul><li><p>Hello <strong>world</strong></p></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Remove a list item from a single-element unordered list, thereby removing the list, too",
                    startHtml: "<ul><li><p>He|llo <strong>world</strong></p></li></ul>",
                    endHtml: "<p>Hello <strong>world</strong></p>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Remove a list item from a single-element ordered list, thereby removing the list, too",
                    startHtml: "<ol><li><p>He|llo <strong>world</strong></p></li></ol>",
                    endHtml: "<p>Hello <strong>world</strong></p>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Remove a list item from a multi-element unordered list, leaving the list in place",
                    startHtml: "<ul><li><p>Hello <strong>wo|rld1</strong></p></li><li><p>Hello <strong>world2</strong></p></li></ul>",
                    endHtml: "<p>Hello <strong>world1</strong></p><ul><li><p>Hello <strong>world2</strong></p></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Change one of the list items in a multi-element unordered list to an ordered list item",
                    startHtml: "<ul><li><p>Hello <strong>wo|rld1</strong></p></li><li><p>Hello <strong>world2</strong></p></li></ul>",
                    endHtml: "<ol><li><p>Hello <strong>world1</strong></p></li></ol><ul><li><p>Hello <strong>world2</strong></p></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Remove UL <ul><li><p>He|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>",
                    startHtml: "<ul><li><p>He|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>",
                    endHtml: "<p>Hello paragraph</p><ul><li><h5>Hello header in list</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outdent <ul><li><p>He|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>",
                    startHtml: "<ul><li><p>He|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>",
                    endHtml: "<p>Hello paragraph</p><ul><li><h5>Hello header in list</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Outdent <ul><li><p>Hello paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul></li></ul>",
                    startHtml: "<ul><li><p>Hello paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul></li></ul>",
                    endHtml: "<ul><li><p>Hello paragraph</p></li><li><h5>Hello header in list</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testMultiLists() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "UL <p>He|llo world1</p><p>He|llo world2</p>",
                    startHtml: "<p>He|llo world1</p><p>He|llo world2</p>",
                    endHtml: "<ul><li><p>Hello world1</p></li><li><p>Hello world2</p></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Remove UL <ul><li><p>He|llo world1</p></li><li><p>He|llo world2</p></li></ul>",
                    startHtml: "<ul><li><p>He|llo world1</p></li><li><p>He|llo world2</p></li></ul>",
                    endHtml: "<p>Hello world1</p><p>Hello world2</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "UL <p>He|llo world1</p><h5>He|llo world2</h5>",
                    startHtml: "<p>He|llo world1</p><h5>He|llo world2</h5>",
                    endHtml: "<ul><li><p>Hello world1</p></li><li><h5>Hello world2</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Remove UL <ul><li><p>He|llo world1</p></li><li><h5>He|llo world2</h5></li></ul>",
                    startHtml: "<ul><li><p>He|llo world1</p></li><li><h5>He|llo world2</h5></li></ul>",
                    endHtml: "<p>Hello world1</p><h5>Hello world2</h5>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "UL <p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                    startHtml: "<p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                    endHtml: "<ul><li><p>Hello paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Remove UL <ul><li><p>He|llo paragraph</p></li><ul><li><h5>He|llo header in list</h5></li></ul></ul>",
                    startHtml: "<ul><li><p>He|llo paragraph</p></li><ul><li><h5>He|llo header in list</h5></li></ul></ul>",
                    endHtml: "<p>Hello paragraph</p><h5>Hello header in list</h5>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "OL <p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                    startHtml: "<p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                    endHtml: "<ol><li><p>Hello paragraph</p><ol><li><h5>Hello header in list</h5></li></ol></li></ol>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Remove OL <ol><li><p>He|llo paragraph</p></li><ol><li><h5>He|llo header in list</h5></li></ol></ol>",
                    startHtml: "<ol><li><p>He|llo paragraph</p></li><ol><li><h5>He|llo header in list</h5></li></ol></ol>",
                    endHtml: "<p>Hello paragraph</p><h5>Hello header in list</h5>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "UL <ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ul>",
                    startHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ul>",
                    endHtml: "<ul><li><h5>Unordered <em>H5</em> list.</h5><ul><li>Ordered sublist.</li></ul></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Remove UL <ul><li><h5>Unordered <em>H5</em> list.</h5><ul><li><p>Unordered sublist.</p></li></ul></li></ul>",
                    startHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ul><li><p>Un|ordered sublist.</p></li></ul></li></ul>",
                    endHtml: "<h5>Unordered <em>H5</em> list.</h5><p>Unordered sublist.</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "OL <ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ul>",
                    startHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ul>",
                    endHtml: "<ol><li><h5>Unordered <em>H5</em> list.</h5><ol><li>Ordered sublist.</li></ol></li></ol>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Remove OL <ol><li><h5>Unordered <em>H5</em> list.</h5><ol><li><p>Ordered sublist.</p></li></ol></li></ol>",
                    startHtml: "<ol><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.</p></li></ol></li></ol>",
                    endHtml: "<h5>Unordered <em>H5</em> list.</h5><p>Ordered sublist.</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "UL interleaved paragraphs and lists",
                    startHtml: "<p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol>",
                    endHtml: "<ul><li><p>Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>Top-level paragraph 2</p><ul><li><p>Ordered list paragraph 1</p></li></ul></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Unset all UL interleaved paragraphs and lists",
                    startHtml: "<ul><li><p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>To|p-level paragraph 2</p><ul><li><p>Ordered list paragraph 1</p></li></ul></li></ul>",
                    endHtml: "<p>Top-level paragraph 1</p><p>Unordered list paragraph 1</p><p>Ordered sublist paragraph</p><p>Top-level paragraph 2</p><p>Ordered list paragraph 1</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Set all OL lists and sublists",
                    startHtml: "<ul><li><p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>To|p-level paragraph 2</p><ul><li><p>Ordered list paragraph 1</p></li></ul></li></ul>",
                    endHtml: "<ol><li><p>Top-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>Top-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol></li></ol>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "OL interleaved paragraphs and lists",
                    startHtml: "<p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol>",
                    endHtml: "<ol><li><p>Top-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>Top-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol></li></ol>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Unset all OL interleaved paragraphs and lists",
                    startHtml: "<ol><li><p>To|p-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol></li></ol>",
                    endHtml: "<p>Top-level paragraph 1</p><p>Unordered list paragraph 1</p><p>Ordered sublist paragraph</p><p>Top-level paragraph 2</p><p>Ordered list paragraph 1</p>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Set all UL lists and sublists",
                    startHtml: "<ol><li><p>To|p-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol></li></ol>",
                    endHtml: "<ul><li><p>Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>Top-level paragraph 2</p><ul><li><p>Ordered list paragraph 1</p></li></ul></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "List operations with selections spanning multiple elements")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testListEnterCollapsed() throws {
        // TODO: Remove... The startHtml includes styled items in the <ul> and unstyled items in the <ol>, and we test both.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Enter at end of h5",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.|</h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5></li><li><h5><br></h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Enter at beginning of h5",
                    startHtml: "<ul><li><h5>|Bulleted <em>item</em> 1.</h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5><br></h5></li><li><h5>Bulleted <em>item</em> 1.</h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Enter in \"Bul|leted item 1.\"",
                    startHtml: "<ul><li><h5>Bul|leted <em>item</em> 1.</h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bul</h5></li><li><h5>leted&nbsp;<em>item</em> 1.</h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Enter in \"Bulleted item 1|.\"",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1|.</h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em>&nbsp;1</h5></li><li><h5>.</h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Enter in italicized \"item\" in \"Bulleted it|em 1.\"",
                    startHtml: "<ul><li><h5>Bulleted <em>it|em</em> 1.</h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>it</em></h5></li><li><h5><em>em</em> 1.</h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Enter at end of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li>Numbered item 1.|</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li>Numbered item 1.</li><li><p><br></p></li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Enter at beginning of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li>|Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p><br></p></li><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Split unstyled \"Number|ed item 1.\"",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li>Number|ed item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li>Number</li><li><p>ed item 1.</p></li><li>Numbered item 2.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Enter in empty list item at end of list.",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li><li><h5>|</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li>Numbered item 1.</li><li>Numbered item 2.</li></ol></li></ul><h5></h5>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Enter being pressed in a list with various collapsed selections")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testListEnterRange() throws {
        // TODO: Remove... The startHtml includes styled items in the <ul> and unstyled items in the <ol>, and we test both.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest.withSelection(
                    description: "Word in single styled list item",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P |Numbered |item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P&nbsp;</p></li><li><p>item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Word in single unstyled list item",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered |item |6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered&nbsp;</li><li><p>6.</p></li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Part of a formatted item in a styled list item",
                    startHtml: "<ul><li><h5>Bulleted <em>i|te|m</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>i</em></h5></li><li><h5><em>m</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "The entire formatted item in a styled list item (note the zero width chars in the result)",
                    startHtml: "<ul><li><h5>Bulleted <em>|item|</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>\u{200B}</em></h5></li><li><h5><em>\u{200B}</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Only the enclosed formatted item in a styled list item (note the zero width chars in the result)",
                    startHtml: "<ul><li><h5>Bulleted <em>|item|</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>\u{200B}</em></h5></li><li><h5><em>\u{200B}</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Begin selection in one styled list item, end in another",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P |Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P |Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P&nbsp;</p></li><li><p>Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Begin selection at start of one unstyled list item, end in another",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>|Numbered item 6.</li><li>Numbered item 7.</li><li>|Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li><p><br></p></li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Begin selection at start of one styled list item, end in another",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>|P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>|P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p><br></p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Begin selection in a styled list item, end in an unstyled one",
                    startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P Num|bered item 1.</p></li><li><p>P Num|bered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Num|bered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Num</p></li><li><p>bered item 7.</p></li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Begin selection in a bulleted list item, end in an ordered unformatted one",
                    startHtml: "<ul><li><h5>Bul|leted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Num|bered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bul|leted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bul</h5></li><li><h5>bered item 7.</h5><ol><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Begin selection in a bulleted list item, end in an ordered formatted one",
                    startHtml: "<ul><li><h5>Bul|leted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Num|bered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bul|leted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bul</h5></li><li><h5>bered item 3.</h5><ol><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Begin selection in a formatted item in a bulleted list item, end in an ordered formatted one",
                    startHtml: "<ul><li><h5>Bulleted <em>it|em</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Num|bered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>it</em></h5></li><li><h5><em>\u{200B}</em>bered item 3.</h5><ol><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Numbered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest.withSelection(
                    description: "Begin selection in a formatted item in a bulleted list item, end in an ordered unformatted one",
                    startHtml: "<ul><li><h5>Bulleted <em>it|em</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li>Numbered item 5.</li><li>Numbered item 6.</li><li>Num|bered item 7.</li><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5>Bulleted <em>it</em></h5></li><li><h5><em>\u{200B}</em>bered item 7.</h5><ol><li>Numbered item 8.</li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>"
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: test.description ?? "Enter being pressed in a list with various range selections")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    action() {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testInsertTable() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest.withSelection(
                description: "Insert in the middle of a paragraph",
                startHtml: "<p>This is a sim|ple paragraph</p>",
                endHtml: "<p>This is a sim</p><table class=\"bordered-table-cell\"><tr><td><p></p></td><td><p></p></td></tr><tr><td><p></p></td><td><p></p></td></tr></table><p>ple paragraph</p>"
            ),
            HtmlTest.withSelection(
                description: "Insert in the end of a paragraph",
                startHtml: "<p>This is a simple paragraph|</p>",
                endHtml: "<p>This is a simple paragraph</p><table class=\"bordered-table-cell\"><tr><td><p></p></td><td><p></p></td></tr><tr><td><p></p></td><td><p></p></td></tr></table>"
            ),
            HtmlTest.withSelection(
                description: "Insert at beginning of a paragraph",
                startHtml: "<p>|This is a simple paragraph</p>",
                endHtml: "<table class=\"bordered-table-cell\"><tr><td><p></p></td><td><p></p></td></tr><tr><td><p></p></td><td><p></p></td></tr></table><p>This is a simple paragraph</p>"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Insert a table")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    self.addInputHandler {
                        self.webView.getRawHtml { formatted in
                            self.assertEqualStrings(expected: endHtml, saw: formatted)
                            expectation.fulfill()
                        }
                    }
                    // Kick off the insert table action
                    self.webView.insertTable(rows: 2, cols: 2)
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testTableActions() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (HtmlTest(
                description: "Delete row",
                startHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.deleteRow() {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Delete col",
                startHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.deleteCol() {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Delete table",
                startHtml: "<p>Hello</p><table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>world</p>",
                endHtml: "<p>Hello</p><p>world</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.deleteTable() {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Add row above",
                startHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p><br></p></td><td><p><br></p></td></tr><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.addRow(.before) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Add row below",
                startHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p><br></p></td><td><p><br></p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.addRow(.after) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Add col before",
                startHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p><br></p></td><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p><br></p></td><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.addCol(.before) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Add col after",
                startHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p><br></p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p><br></p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.addCol(.after) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Add header",
                startHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><thead><tr><th colspan=\"2\"><p><br></p></th></tr></thead><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.addHeader() {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Set cell border",
                startHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table>",
                endHtml: "<table class=\"bordered-table-cell\"><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.borderTable(.cell) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Set header border",
                startHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table>",
                endHtml: "<table class=\"bordered-table-header\"><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.borderTable(.header) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Set outer border",
                startHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table>",
                endHtml: "<table class=\"bordered-table-outer\"><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.borderTable(.outer) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Set no border",
                startHtml: "<table><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table>",
                endHtml: "<table class=\"bordered-table-none\"><tbody><tr><td><p>Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></tbody></table>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.borderTable(.none) {
                     handler()
                 }
             }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Perform actions on a table")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                     self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        action {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    /// Test preprocessing of HTML that is performed before pasting.
    ///
    /// Text that comes in via the pasteboard contains a "proper" HTML document, including meta tags and extensive
    /// styling to capture the state from the source document. The MarkupEditor strictly controls the styling and other
    /// content of the document it works on, so much of this content needs to be stripped from the incoming HTML
    /// before pasting. By testing the preprocessing itself, the tests for HTML paste (and the corresponding text paste)
    /// can be done using "clean" strings.
    func testPasteHtmlPreprocessing() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Clean HTML should not change",
                startHtml: "<h5>This is just a simple paragraph.</h5>",
                endHtml: "<h5>This is just a simple paragraph.</h5>",
                startId: "h5",
                startOffset: 10,
                endId: "h5",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up a simple copy buffer of h1 from the MarkupEditor",
                startHtml: "<h1 style=\"font-size: 2.5em; font-weight: bold; margin: 0px 0px 10px; caret-color: rgb(0, 0, 255); color: rgba(0, 0, 0, 0.847); font-family: UICTFontTextStyleBody; font-style: normal; font-variant-caps: normal; letter-spacing: normal; orphans: auto; text-align: start; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-tap-highlight-color: rgba(26, 26, 26, 0.3); -webkit-text-size-adjust: none; -webkit-text-stroke-width: 0px; text-decoration: none;\">Welcome to the MarkupEditor Demo</h1><br class=\"Apple-interchange-newline\">",
                endHtml: "<h1>Welcome to the MarkupEditor Demo</h1><p><br></p>",
                startId: "h1",
                startOffset: 10,
                endId: "h1",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up text that includes HTML",
                startHtml: "<p>These are angle brackets: < and >.</p>",
                endHtml: "<p>These are angle brackets: &lt; and &gt;.</p>",
                startId: "p",
                startOffset: 0,
                endId: "p",
                endOffset: 0
            ),
            HtmlTest(
                description: "Copy/paste from VSCode",
                startHtml: "<meta charset='utf-8'><div style=\"color: #d4d4d4;background-color: #1e1e1e;font-family: Menlo, Monaco, 'Courier New', monospace;font-weight: normal;font-size: 12px;line-height: 18px;white-space: pre;\"><div><span style=\"color: #d4d4d4;\">Hello </span><span style=\"color: #808080;\">&lt;</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\">bold</span><span style=\"color: #808080;\">&lt;/</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\"> world</span></div></div>",
                endHtml: "<p>Hello &lt;b&gt;bold&lt;/b&gt; world</p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                // From https://stackoverflow.com/a/50547246/8968411
                description: "Clean up complex content from StackOverflow",
                startHtml: "<meta charset=\"UTF-8\"><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">List of One Liners</strong></p><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\">Let\'s solve this problem for this array:</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\"><span class=\"hljs-keyword\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-keyword);\">var</span> array = [<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'A\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'C\'</span>];\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">1. Remove only the first:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">indexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">2. Remove only the last:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">lastIndexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">3. Remove all occurrences:</strong></p><pre class=\"lang-js s-code-block\" style=\"margin: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array = array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">filter</span>(<span class=\"hljs-function\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\"><span class=\"hljs-params\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\">v</span> =&gt;</span> v !== <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>); </code></pre>",
                endHtml: "<p><strong>List of One Liners</strong></p><p>Let\'s solve this problem for this array:</p><p><code>var array = [\'A\', \'B\', \'C\'];</code></p><p><strong>1. Remove only the first:</strong>&nbsp;Use If you are sure that the item exist</p><p><code>array.splice(array.indexOf(\'B\'), 1);</code></p><p><strong>2. Remove only the last:</strong>&nbsp;Use If you are sure that the item exist</p><p><code>array.splice(array.lastIndexOf(\'B\'), 1);</code></p><p><strong>3. Remove all occurrences:</strong></p><p><code>array = array.filter(v =&gt; v !== \'B\'); </code></p>",
                startId: "p", 
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Simple multiline text from MacOS Notes",
                startHtml: "This is a test<br><br>Of a note<br>But what is this?",
                endHtml: "<p>This is a test<br><br>Of a note<br>But what is this?</p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Trailing <BR> in MacOS Notes",
                startHtml: "This is a test<br>",
                endHtml: "<p>This is a test<br></p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Rosetta Stone from iOS Notes",
                startHtml: "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">\n<html>\n<head>\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">\n<meta http-equiv=\"Content-Style-Type\" content=\"text/css\">\n<title></title>\n<meta name=\"Generator\" content=\"Cocoa HTML Writer\">\n<style type=\"text/css\">\np.p1 {margin: 0.0px 0.0px 3.0px 0.0px; font: 28.0px \'.AppleSystemUIFont\'}\np.p2 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'; min-height: 22.0px}\np.p3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\np.p4 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.Apple Color Emoji UI\'}\np.p5 {margin: 9.0px 0.0px 8.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nli.li3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nspan.s1 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 28.00px}\nspan.s2 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.s3 {font-family: \'UICTFontTextStyleEmphasizedBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s4 {font-family: \'UICTFontTextStyleItalicBody\'; font-weight: normal; font-style: italic; font-size: 17.00px}\nspan.s5 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px; text-decoration: underline}\nspan.s6 {font-family: \'UICTFontTextStyleEmphasizedItalicBody\'; font-weight: bold; font-style: italic; font-size: 17.00px; text-decoration: underline}\nspan.s7 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s8 {font-family: \'.AppleColorEmojiUI\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.Apple-tab-span {white-space:pre}\ntable.t1 {border-collapse: collapse}\ntd.td1 {border-style: solid; border-width: 1.0px 1.0px 1.0px 1.0px; border-color: #aaaaaa #aaaaaa #aaaaaa #aaaaaa; padding: 1.0px 5.0px 1.0px 5.0px}\nol.ol1 {list-style-type: decimal}\nul.ul1 {list-style-type: circle}\nul.ul2 {list-style-type: \'✓  \'}\nul.ul3 {list-style-type: disc}\n</style>\n</head>\n<body>\n<p class=\"p1\"><span class=\"s1\">Notes Test for MarkupEditor</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\"><span class=\"Apple-tab-span\">\t</span>An indented paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p3\"><span class=\"s2\">With another immediately below.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph with </span><span class=\"s3\">bold</span><span class=\"s2\">, </span><span class=\"s4\">italic</span><span class=\"s2\">, and </span><span class=\"s5\">underline</span><span class=\"s2\"> , and </span><span class=\"s6\">combo formatting</span><span class=\"s2\"> in it and a <a href=\"http://foo.com\">link</a>.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul1\">\n<li class=\"li3\"><span class=\"s2\">A checklist</span></li>\n</ul>\n<ul class=\"ul2\">\n<li class=\"li3\"><span class=\"s2\">With a checked item</span></li>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p1\"><span class=\"s1\">A Title</span></p>\n<p class=\"p3\"><span class=\"s7\">A Subtitle</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">A numbered list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ol>\n</ol>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">A bulleted list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ul>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<table cellspacing=\"0\" cellpadding=\"0\" class=\"t1\">\n<tbody>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">A table</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">With two columns</span></p>\n</td>\n</tr>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">And two rows</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p4\"><span class=\"s8\">😜</span></p>\n</td>\n</tr>\n</tbody>\n</table>\n<p class=\"p3\"><span class=\"s2\">And here is an image…</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p5\"><span class=\"s2\"><img src=\"file:///Pasted%20Graphic.png\" alt=\"Pasted Graphic.png\"></span></p>\n</body>\n</html>\n",
                endHtml: "<p>Notes Test for MarkupEditor</p><p><br></p><p>A paragraph&nbsp;</p><p><br></p><p>&nbsp;&nbsp;&nbsp;&nbsp;An indented paragraph&nbsp;</p><p><br></p><p>A paragraph&nbsp;</p><p>With another immediately below.</p><p><br></p><p>A paragraph with bold, italic, and underline , and combo formatting in it and a <a href=\"http://foo.com\">link</a>.</p><p><br></p><ul><li>A checklist</li></ul><ul><li>With a checked item</li></ul><p><br></p><p>A Title</p><p>A Subtitle</p><p><br></p><ol><li>A numbered list</li><li>With two items</li><ol><li>One of which has a subitem</li></ol></ol><p><br></p><ul><li>A bulleted list</li><li>With two items</li><ul><li>One of which has a subitem</li></ul></ul><p><br></p><table cellspacing=\"0\" cellpadding=\"0\"><tbody><tr><td valign=\"top\"><p>A table</p></td><td valign=\"top\"><p>With two columns</p></td></tr><tr><td valign=\"top\"><p>And two rows</p></td><td valign=\"top\"><p>😜</p></td></tr></tbody></table><p>And here is an image…</p><p><br></p><p><img src=\"file:///Pasted%20Graphic.png\" alt=\"Pasted Graphic.png\"></p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Cleaning up html we get from the paste buffer")
            self.webView.testPasteHtmlPreprocessing(html: startHtml) { cleaned in
                self.assertEqualStrings(expected: endHtml, saw: cleaned)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testPasteHtml() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded HTML at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is juHello &lt;b&gt;bold&lt;/b&gt; worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello &lt;b&gt;bold&lt;/b&gt; world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded bold at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is juHello <strong>bold</strong> worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello <strong>bold</strong> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a bolded word",
                startHtml: "<p>This is <strong>just</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>juHello worldst</strong> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded italic at insertion point in a bolded word",
                startHtml: "<p>This is <strong>just</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>juHello <em>bold</em> worldst</strong> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello <em>bold</em> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is juHello <strong>bold</strong> worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a bolded word",
                startHtml: "<p>This is <strong>just</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>juHello <em>bold</em> worldst</strong> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "<p>Hello <em>bold</em> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at beginning of another",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>Hello worldThis is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at beginning of another",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>Hello <strong>bold</strong> worldThis is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at end of another",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is just a simple paragraph.Hello world</p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at end of another",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is just a simple paragraph.Hello <strong>bold</strong> world</p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p><br></p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p><br></p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello <strong>bold</strong> world</p>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "H5 in P - Paste simple h5 at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p><br></p>",
                endHtml: "<p>This is just a simple paragraph.</p><h5>Hello world</h5>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello world</h5>"
            ),
            HtmlTest(
                description: "H5 in P - Paste h5 with children at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p><br></p>",
                endHtml: "<p>This is just a simple paragraph.</p><h5>Hello <strong>bold</strong> world</h5>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello <strong>bold</strong> world</h5>"
            ),
            HtmlTest(
                description: "P in Empty Document - Paste multiple paragraphs into an empty document",
                startHtml: "<p><br></p>",
                endHtml: "<h1>A title</h1><h2>A subtitle</h2><p>A paragraph.</p>",
                startId: "blank",     // Select "|"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h1>A title</h1><h2>A subtitle</h2><p>A paragraph.</p>"
            ),
            // Tables
            HtmlTest(
                description: "TABLE in P - Paste a table at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p><br></p>",
                endHtml: "<p>This is just a simple paragraph.</p><table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table>"
            ),
            HtmlTest(
                description: "TABLE in P - Paste a table at beginning of a paragraph",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table><p>This is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table>"
            ),
            HtmlTest(
                description: "TABLE in P - Paste a table at end of a paragraph",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is just a simple paragraph.</p><table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table>"
            ),
            HtmlTest(
                description: "TABLE in P - Paste a table in text of a paragraph",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is ju</p><table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table><p>st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st"
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table>"
            ),
            HtmlTest(
                description: "TABLE in P - Paste a table in formatted text of a paragraph",
                startHtml: "<p>This is <strong>just</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong></p><table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table><p><strong>st</strong> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st"
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "<table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table>"
            ),
            HtmlTest(
                description: "P in P - Paste a simple paragraph at a blank line after a table",
                startHtml: "<table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table><p><br></p>",
                endHtml: "<table><tbody><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></tbody></table><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            // Lists
            HtmlTest(
                description: "OL in P - Paste a list at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p><br></p>",
                endHtml: "<p>This is just a simple paragraph.</p><ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>"
            ),
            HtmlTest(
                description: "OL in P - Paste a list at beginning of a paragraph",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol><p>This is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>"
            ),
            HtmlTest(
                description: "OL in P - Paste a list at end of a paragraph",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is just a simple paragraph.</p><ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>"
            ),
            HtmlTest(
                description: "OL in P - Paste a list in text of a paragraph",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is ju</p><ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol><p>st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st"
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>"
            ),
            HtmlTest(
                description: "OL in P - Paste a list in formatted text of a paragraph",
                startHtml: "<p>This is <strong>just</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong></p><ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol><p><strong>st</strong> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st"
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>"
            ),
            HtmlTest(
                description: "P in P - Paste a simple paragraph at a blank line after a list",
                startHtml: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol><p><br></p>",
                endHtml: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            // Blockquotes
            HtmlTest(
                description: "BLOCKQUOTE in P - Paste a BLOCKQUOTE at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p><br></p>",
                endHtml: "<p>This is just a simple paragraph.</p><blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>"
            ),
            HtmlTest(
                description: "BLOCKQUOTE in P - Paste a BLOCKQUOTE at beginning of a paragraph",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote><p>This is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>"
            ),
            HtmlTest(
                description: "BLOCKQUOTE in P - Paste a BLOCKQUOTE at end of a paragraph",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is just a simple paragraph.</p><blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>"
            ),
            HtmlTest(
                description: "BLOCKQUOTE in P - Paste a BLOCKQUOTE in text of a paragraph",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is ju</p><blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote><p>st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st"
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>"
            ),
            HtmlTest(
                description: "BLOCKQUOTE in P - Paste a BLOCKQUOTE in formatted text of a paragraph",
                startHtml: "<p>This is <strong>just</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong></p><blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote><p><strong>st</strong> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st"
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>"
            ),
            HtmlTest(
                description: "P in P - Paste a simple paragraph at a blank line after a BLOCKQUOTE",
                startHtml: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote><p><br></p>",
                endHtml: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Paste various html at various places")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                     self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteHtml(test.pasteString) {
                            self.webView.getRawHtml() { pasted in
                                self.assertEqualStrings(expected: endHtml, saw: pasted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    /// Test preprocessing of HTML that is performed before pasting text (aka "Paste and Match Style").
    ///
    /// See comments in the `testPasteHtmlPreprocessing` method.
    ///
    /// The "pasteText" function (via the "Paste and Match Style" edit menu) pastes the MarkupEditor
    /// equivalent of plain text. To do that, it uses <p> for all styling and removes all formatting (e.g., <strong>, <em>, etc).
    /// The text preprocessing does the same preprocessing as the HTML preprocessing, plus this additional
    /// style and format removal, along with link removal.
    func testPasteTextPreprocessing() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Clean HTML should not change",
                startHtml: "<h5>This is just a simple paragraph.</h5>",
                endHtml: "<p>This is just a simple paragraph.</p>",
                startId: "h5",
                startOffset: 10,
                endId: "h5",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up a simple copy buffer of h1 from the MarkupEditor",
                startHtml: "<h1 style=\"font-size: 2.5em; font-weight: bold; margin: 0px 0px 10px; caret-color: rgb(0, 0, 255); color: rgba(0, 0, 0, 0.847); font-family: UICTFontTextStyleBody; font-style: normal; font-variant-caps: normal; letter-spacing: normal; orphans: auto; text-align: start; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-tap-highlight-color: rgba(26, 26, 26, 0.3); -webkit-text-size-adjust: none; -webkit-text-stroke-width: 0px; text-decoration: none;\">Welcome to the MarkupEditor Demo</h1><br class=\"Apple-interchange-newline\">",
                endHtml: "<p>Welcome to the MarkupEditor Demo</p><p><br></p>",
                startId: "h1",
                startOffset: 10,
                endId: "h1",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up text that includes HTML",
                startHtml: "<p>These are angle brackets: < and >.</p>",
                endHtml: "<p>These are angle brackets: &lt; and &gt;.</p>",
                startId: "p",
                startOffset: 0,
                endId: "p",
                endOffset: 0
            ),
            HtmlTest(
                description: "Copy/paste from VSCode",
                startHtml: "<meta charset='utf-8'><div style=\"color: #d4d4d4;background-color: #1e1e1e;font-family: Menlo, Monaco, 'Courier New', monospace;font-weight: normal;font-size: 12px;line-height: 18px;white-space: pre;\"><div><span style=\"color: #d4d4d4;\">Hello </span><span style=\"color: #808080;\">&lt;</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\">bold</span><span style=\"color: #808080;\">&lt;/</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\"> world</span></div></div>",
                endHtml: "<p>Hello &lt;b&gt;bold&lt;/b&gt; world</p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up complex content from StackOverflow",
                startHtml: "<meta charset=\"UTF-8\"><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">List of One Liners</strong></p><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\">Let\'s solve this problem for this array:</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\"><span class=\"hljs-keyword\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-keyword);\">var</span> array = [<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'A\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'C\'</span>];\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">1. Remove only the first:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">indexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">2. Remove only the last:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">lastIndexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">3. Remove all occurrences:</strong></p><pre class=\"lang-js s-code-block\" style=\"margin: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array = array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">filter</span>(<span class=\"hljs-function\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\"><span class=\"hljs-params\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\">v</span> =&gt;</span> v !== <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>); </code></pre>",
                endHtml: "<p>List of One Liners</p><p>Let\'s solve this problem for this array:</p><p>var array = [\'A\', \'B\', \'C\'];</p><p>1. Remove only the first:&nbsp;Use If you are sure that the item exist</p><p>array.splice(array.indexOf(\'B\'), 1);</p><p>2. Remove only the last:&nbsp;Use If you are sure that the item exist</p><p>array.splice(array.lastIndexOf(\'B\'), 1);</p><p>3. Remove all occurrences:</p><p>array = array.filter(v =&gt; v !== \'B\'); </p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up some text from Xcode",
                startHtml: "const _pasteHTML = function(html, oldUndoerData, undoable=true) {\n    const redoing = !undoable && (oldUndoerData !== null);\n    let sel = document.getSelection();\n    let anchorNode = (sel) ? sel.anchorNode : null;\n    if (!anchorNode) {\n        MUError.NoSelection.callback();\n        return null;\n    };",
                endHtml: "<p>const _pasteHTML = function(html, oldUndoerData, undoable=true) {<br>&nbsp;&nbsp;&nbsp;&nbsp;const redoing = !undoable &amp;&amp; (oldUndoerData !== null);<br>&nbsp;&nbsp;&nbsp;&nbsp;let sel = document.getSelection();<br>&nbsp;&nbsp;&nbsp;&nbsp;let anchorNode = (sel) ? sel.anchorNode : null;<br>&nbsp;&nbsp;&nbsp;&nbsp;if (!anchorNode) {<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;MUError.NoSelection.callback();<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;return null;<br>&nbsp;&nbsp;&nbsp;&nbsp;};</p>",
                startId: "h1",
                startOffset: 10,
                endId: "h1",
                endOffset: 10
            ),
            HtmlTest(
                description: "Simple multiline text from MacOS Notes",
                startHtml: "This is a test<br><br>Of a note<br>But what is this?",
                endHtml: "<p>This is a test<br><br>Of a note<br>But what is this?</p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Trailing <BR> in MacOS Notes",
                startHtml: "This is a test<br>",
                endHtml: "<p>This is a test<br></p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Rosetta Stone from iOS Notes",
                startHtml: "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">\n<html>\n<head>\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">\n<meta http-equiv=\"Content-Style-Type\" content=\"text/css\">\n<title></title>\n<meta name=\"Generator\" content=\"Cocoa HTML Writer\">\n<style type=\"text/css\">\np.p1 {margin: 0.0px 0.0px 3.0px 0.0px; font: 28.0px \'.AppleSystemUIFont\'}\np.p2 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'; min-height: 22.0px}\np.p3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\np.p4 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.Apple Color Emoji UI\'}\np.p5 {margin: 9.0px 0.0px 8.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nli.li3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nspan.s1 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 28.00px}\nspan.s2 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.s3 {font-family: \'UICTFontTextStyleEmphasizedBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s4 {font-family: \'UICTFontTextStyleItalicBody\'; font-weight: normal; font-style: italic; font-size: 17.00px}\nspan.s5 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px; text-decoration: underline}\nspan.s6 {font-family: \'UICTFontTextStyleEmphasizedItalicBody\'; font-weight: bold; font-style: italic; font-size: 17.00px; text-decoration: underline}\nspan.s7 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s8 {font-family: \'.AppleColorEmojiUI\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.Apple-tab-span {white-space:pre}\ntable.t1 {border-collapse: collapse}\ntd.td1 {border-style: solid; border-width: 1.0px 1.0px 1.0px 1.0px; border-color: #aaaaaa #aaaaaa #aaaaaa #aaaaaa; padding: 1.0px 5.0px 1.0px 5.0px}\nol.ol1 {list-style-type: decimal}\nul.ul1 {list-style-type: circle}\nul.ul2 {list-style-type: \'✓  \'}\nul.ul3 {list-style-type: disc}\n</style>\n</head>\n<body>\n<p class=\"p1\"><span class=\"s1\">Notes Test for MarkupEditor</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\"><span class=\"Apple-tab-span\">\t</span>An indented paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p3\"><span class=\"s2\">With another immediately below.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph with </span><span class=\"s3\">bold</span><span class=\"s2\">, </span><span class=\"s4\">italic</span><span class=\"s2\">, and </span><span class=\"s5\">underline</span><span class=\"s2\"> , and </span><span class=\"s6\">combo formatting</span><span class=\"s2\"> in it and a <a href=\"http://foo.com\">link</a>.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul1\">\n<li class=\"li3\"><span class=\"s2\">A checklist</span></li>\n</ul>\n<ul class=\"ul2\">\n<li class=\"li3\"><span class=\"s2\">With a checked item</span></li>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p1\"><span class=\"s1\">A Title</span></p>\n<p class=\"p3\"><span class=\"s7\">A Subtitle</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">A numbered list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ol>\n</ol>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">A bulleted list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ul>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<table cellspacing=\"0\" cellpadding=\"0\" class=\"t1\">\n<tbody>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">A table</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">With two columns</span></p>\n</td>\n</tr>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">And two rows</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p4\"><span class=\"s8\">😜</span></p>\n</td>\n</tr>\n</tbody>\n</table>\n<p class=\"p3\"><span class=\"s2\">And here is an image…</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p5\"><span class=\"s2\"><img src=\"file:///Pasted%20Graphic.png\" alt=\"Pasted Graphic.png\"></span></p>\n</body>\n</html>\n",
                endHtml: "<p>Notes Test for MarkupEditor</p><p><br></p><p>A paragraph&nbsp;</p><p><br></p><p>&nbsp;&nbsp;&nbsp;&nbsp;An indented paragraph&nbsp;</p><p><br></p><p>A paragraph&nbsp;</p><p>With another immediately below.</p><p><br></p><p>A paragraph with bold, italic, and underline , and combo formatting in it and a link.</p><p><br></p><ul><li>A checklist</li></ul><ul><li>With a checked item</li></ul><p><br></p><p>A Title</p><p>A Subtitle</p><p><br></p><ol><li>A numbered list</li><li>With two items</li><ol><li>One of which has a subitem</li></ol></ol><p><br></p><ul><li>A bulleted list</li><li>With two items</li><ul><li>One of which has a subitem</li></ul></ul><p><br></p><table cellspacing=\"0\" cellpadding=\"0\"><tbody><tr><td valign=\"top\"><p>A table</p></td><td valign=\"top\"><p>With two columns</p></td></tr><tr><td valign=\"top\"><p>And two rows</p></td><td valign=\"top\"><p>😜</p></td></tr></tbody></table><p>And here is an image…</p><p><br></p><p><img src=\"file:///Pasted%20Graphic.png\" alt=\"Pasted Graphic.png\"></p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Get \"unformatted text\" from the paste buffer")
            self.webView.testPasteTextPreprocessing(html: startHtml) { cleaned in
                self.assertEqualStrings(expected: endHtml, saw: cleaned)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testPasteText() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded HTML at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is juHello &lt;b&gt;bold&lt;/b&gt; worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello &lt;b&gt;bold&lt;/b&gt; world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded bold at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is juHello bold worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello <strong>bold</strong> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a bolded word",
                startHtml: "<p>This is <strong>just</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>juHello worldst</strong> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded italic at insertion point in a bolded word",
                startHtml: "<p>This is <strong>just</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>juHello bold worldst</strong> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello <em>bold</em> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is juHello bold worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a bolded word",
                startHtml: "<p>This is <strong>just</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>juHello bold worldst</strong> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "<p>Hello <em>bold</em> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at beginning of another",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>Hello worldThis is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at beginning of another",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>Hello bold worldThis is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at end of another",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is just a simple paragraph.Hello world</p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at end of another",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is just a simple paragraph.Hello bold world</p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p><br></p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p><br></p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello bold world</p>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "H5 in P - Paste simple h5 at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p><br></p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello world</h5>"
            ),
            HtmlTest(
                description: "H5 in P - Paste h5 with children at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p><br></p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello bold world</p>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello <strong>bold</strong> world</h5>"
            ),
            HtmlTest(
                description: "P in Empty Document - Paste multiple paragraphs into an empty document",
                startHtml: "<p><br></p>",
                endHtml: "<p>A title</p><p>A subtitle</p><p>A paragraph.</p>",
                startId: "blank",     // Select "|"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h1>A title</h1><h2>A subtitle</h2><p>A paragraph.</p>"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Paste various html at various places")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                     self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteText(test.pasteString) {
                            self.webView.getRawHtml() { pasted in
                                self.assertEqualStrings(expected: endHtml, saw: pasted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testPasteImage() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Image in P - Paste image at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Paste an image")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                     self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteImage(UIImage(systemName: "calendar")) {
                            self.webView.getRawHtml() { pasted in
                                if let imageFileName = pasted?.imageFileNameInTag() {
                                    XCTAssertTrue(self.webView.resourceExists(imageFileName))
                                    expectation.fulfill()
                                } else {
                                    XCTFail("The pasted HTML was not returned properly.")
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testPasteImageUrl() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "MP4 URL in P - Paste image URL at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is ju<img src=\"https://github.com/stevengharris/MarkupEditor/foo.mp4\">st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.mp4"
            ),
            HtmlTest(
                description: "JPG URL in P - Paste image URL at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is ju<img src=\"https://github.com/stevengharris/MarkupEditor/foo.jpg\">st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.jpg"
            ),
            HtmlTest(
                description: "PNG URL in P - Paste image URL at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is ju<img src=\"https://github.com/stevengharris/MarkupEditor/foo.png\">st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.png"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Paste an image URL")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                     self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteUrl(url: URL(string: test.pasteString!)) {
                            self.webView.getRawHtml() { pasted in
                                self.assertEqualStrings(expected: test.endHtml, saw: pasted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testPasteLink() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Link in P - Paste link at insertion point in a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is <a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">just</a> a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at end of a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is just<a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a> a simple paragraph.</p>",
                startId: "p",     // Select "just|"
                startOffset: 12,
                endId: "p",
                endOffset: 12,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at beginning of a word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is <a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a>just a simple paragraph.</p>",
                startId: "p",     // Select "|just"
                startOffset: 8,
                endId: "p",
                endOffset: 8,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at beginning of paragraph",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p><a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a>This is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at end of paragraph",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "<p>This is just a simple paragraph.<a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a></p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Paste a link")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                     self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteUrl(url: URL(string: test.pasteString!)) {
                            self.webView.getRawHtml() { pasted in
                                self.assertEqualStrings(expected: test.endHtml, saw: pasted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    // Repurpose the endHtml, undoHtml, and pasteString state in HtmlTest as commented below for search tests
    func testSearch() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Exact word match",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "just",        // Search forward result
                undoHtml: "just",       // Search backward result
                startId: "p",           // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "just"     // Search for
            ),
            HtmlTest(
                description: "Partial word match",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "us",          // Search forward result
                undoHtml: "us",         // Search backward result
                startId: "p",           // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "us"       // Search for
            ),
            HtmlTest(
                description: "Mixed case word match",
                startHtml: "<p>This is just a SiMpLe paragraph.</p>",
                endHtml: "SiMpLe",      // Search forward result
                undoHtml: "SiMpLe",     // Search backward result
                startId: "p",           // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "simple"   // Search for
            ),
            HtmlTest(
                description: "Mixed case search for lowercase word",
                startHtml: "<p>This is just a simple paragraph.</p>",
                endHtml: "simple",      // Search forward result
                undoHtml: "simple",     // Search backward result
                startId: "p",           // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "SiMpLe"   // Search for
            ),
            HtmlTest(
                description: "Search with apostrophe",
                startHtml: "<p>This isn't just a simple paragraph.</p>",
                endHtml: "isn't",       // Search forward result
                undoHtml: "isn't",      // Search backward result
                startId: "p",           // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "isn't"     // Search for
            ),
            HtmlTest(
                description: "Search with apostrophe and quotes",
                startHtml: "<p>This isn't just a \"simple\" paragraph.</p>",
                endHtml: "isn't just a \"simple\"",         // Search forward result
                undoHtml: "isn't just a \"simple\"",        // Search backward result
                startId: "p",                               // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "isn't just a \"simple\""      // Search for
            ),
            HtmlTest(
                description: "Search with smart quotes",
                startHtml: "<p>This isn't just a \"simple\" paragraph.</p>",
                endHtml: "\"simple\"",          // Search forward result
                undoHtml: "\"simple\"",         // Search backward result
                startId: "p",                   // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "“simple”"         // Search for
            ),
            HtmlTest(
                description: "Search with smart apostrophe",
                startHtml: "<p>This isn't just a \"simple\" paragraph.</p>",
                endHtml: "isn't",               // Search forward result
                undoHtml: "isn't",              // Search backward result
                startId: "p",                   // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "isn’t"            // Search for
            ),
            HtmlTest(
                description: "Search with mixed smart apostrophe and quotes",
                startHtml: "<p>This isn't just a \"simple\" paragraph.</p>",
                endHtml: "isn't just a \"simple\"",         // Search forward result
                undoHtml: "isn't just a \"simple\"",        // Search backward result
                startId: "p",                               // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "isn’t just a “simple”"        // Search for
            ),
            HtmlTest(
                description: "Search relative to selection",
                startHtml: "<p>This is just a SiMpLe word in a sImPlE paragraph.</p>",
                endHtml: "sImPlE",      // Search forward result
                undoHtml: "SiMpLe",     // Search backward result
                startId: "p",           // Select "word|"
                startOffset: 26,
                endId: "p",
                endOffset: 26,
                pasteString: "simple"   // Search for
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let searchString = test.pasteString ?? ""
            let expectation = XCTestExpectation(description: "Search forward and backward")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                     self.assertEqualStrings(expected: self.withoutSelection(startHtml), saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.search(for: searchString, direction: .forward) {
                            self.webView.getSelectionState() { state in
                                XCTAssertTrue(state.selection == test.endHtml)   // Selection extends beyond word!
                                self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                                    self.webView.search(for: searchString, direction: .backward) {
                                        self.webView.getSelectionState() { state in
                                            // In some cases, selection extends beyond a word to include blanks. Not sure if this is a bug, frankly.
                                            XCTAssertTrue(state.selection == test.undoHtml)
                                            expectation.fulfill()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }

}
