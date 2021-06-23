//
//  MarkupEditorTests.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 3/5/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import XCTest
import MarkupEditor

struct HtmlTest {
    var startHtml: String
    var endHtml: String
    var startId: String
    var startOffset: Int
    var endId: String
    var endOffset: Int
    
    static func forFormatting(_ rawString: String, style: StyleContext, format: FormatContext, startingAt startOffset: Int, endingAt endOffset: Int) -> HtmlTest {
        // Return an HTMLTest appropriate for formatting a range from startOffset to endOffset in styled HTML
        // For example, to test bolding of the word "is" in the following: <p id: "p">This is a start.</p>, use:
        //      HtmlTest.forFormatting("This is a start.", style: .P, format: .B, startingAt: 5, endingAt: 7)
        // This populates the HtmlTest as follows:
        //  - startHtml : "<p id=\"p\">This is a start.</p>"
        //  - endHtml : "<p id=\"p\">This <b>is</b> a start.</p>"
        //  - startId : "p"
        //  - startOffset : 5
        //  - endId : "p"
        //  - endOffset : 7
        let lcTag = style.tag.lowercased()
        let styledWithId = rawString.styledHtml(adding: style, withId: lcTag)
        let formattedOnly = rawString.formattedHtml(adding: format, startingAt: startOffset, endingAt: endOffset)
        let styledAndFormatted = formattedOnly.styledHtml(adding: style, withId: lcTag)
        return HtmlTest(startHtml: styledWithId, endHtml: styledAndFormatted, startId: lcTag, startOffset: startOffset, endId: lcTag, endOffset: endOffset)
    }
    
    static func forUnformatting(_ rawString: String, style: StyleContext, format: FormatContext, startingAt startOffset: Int, endingAt endOffset: Int) -> HtmlTest {
        // Return an HTMLTest appropriate for unformatting a range from startOffset to endOffset in styled HTML
        // For example, to test unbolding of the word "is" in the following: <p>This <b id: "b">is</b> a start.</p>, use:
        //      HtmlTest.forUnformatting("This is a start.", style: .P, format: .B, startingAt: 5, endingAt: 7)
        // This populates the HtmlTest as follows:
        // - startHtml : "<p>This <b id=\"b\">is</b> a start.</p>"
        // - endHtml : "<p>This is a start.</p>"
        // - startId : "b"
        // - startOffset : 0
        // - endId : "b"
        // - endOffset : 2
        let lcTag = format.tag.lowercased()
        let styledOnly = rawString.styledHtml(adding: style)
        let formattedWithId = rawString.formattedHtml(adding: format, startingAt: startOffset, endingAt: endOffset, withId: lcTag)
        let styledAndFormatted = formattedWithId.styledHtml(adding: style)
        return HtmlTest(startHtml: styledAndFormatted, endHtml: styledOnly, startId: lcTag, startOffset: 0, endId: lcTag, endOffset: endOffset - startOffset)
    }
    
}

class MarkupEditorTests: XCTestCase, MarkupDelegate {
    var selectionState: SelectionState = SelectionState()
    var webView: MarkupWKWebView!
    var coordinator: MarkupCoordinator!
    var loadedExpectation: XCTestExpectation = XCTestExpectation(description: "Loaded")
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        webView = MarkupWKWebView()
        coordinator = MarkupCoordinator(selectionState: selectionState, markupDelegate: self, webView: webView)
        // The coordinator will receive callbacks from markup.js
        // using window.webkit.messageHandlers.test.postMessage(<message>);
        webView.configuration.userContentController.add(coordinator, name: "markup")
        wait(for: [loadedExpectation], timeout: 1)
    }
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        // Since we marked self as the markupDelegate, we receive the markupDidLoad message
        loadedExpectation.fulfill()
        handler?()
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testLoad() throws {
        // Do nothing other than run setupWithError
    }

    func testStyles() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (   // Replace p with h1
                HtmlTest(
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<h1><b id=\"b\"><i id=\"i\">Hello </i>world</b></h1>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (   // Replace h2 with h6
                HtmlTest(
                    startHtml: "<h2 id=\"h2\">Hello world</h2>",
                    endHtml: "<h6>Hello world</h6>",
                    startId: "h2",
                    startOffset: 0,
                    endId: "h2",
                    endOffset: 10
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H6) {
                            handler()
                        }
                    }
                }
            ),
            (   // Replace h3 with p
                HtmlTest(
                    startHtml: "<h3 id=\"h3\">Hello world</h3>",
                    endHtml: "<p>Hello world</p>",
                    startId: "h3",
                    startOffset: 2,
                    endId: "h3",
                    endOffset: 8
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .P) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Setting and replacing styles")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == startHtml)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == endHtml, "Expected \(endHtml), saw: \(formatted ?? "nil")")
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }

    func testUndoStyles() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (   // Replace p with h1
                HtmlTest(
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H1) {
                            self.webView.testUndo() {
                                handler()
                            }
                        }
                    }
                }
            ),
            (   // Replace h2 with h6
                HtmlTest(
                    startHtml: "<h2 id=\"h2\">Hello world</h2>",
                    endHtml: "<h2>Hello world</h2>",
                    startId: "h2",
                    startOffset: 0,
                    endId: "h2",
                    endOffset: 10
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .H6) {
                            self.webView.testUndo() {
                                handler()
                            }
                        }
                    }
                }
            ),
            (   // Replace h3 with p
                HtmlTest(
                    startHtml: "<h3 id=\"h3\">Hello world</h3>",
                    endHtml: "<h3>Hello world</h3>",
                    startId: "h3",
                    startOffset: 2,
                    endId: "h3",
                    endOffset: 8
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(in: state, with: .P) {
                            self.webView.testUndo() {
                                handler()
                            }
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Undoing the setting and replacing of styles")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == startHtml)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == endHtml, "Expected \(endHtml), saw: \(formatted ?? "nil")")
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    

    func testFormats() throws {
        // Select a range in a P styled string, apply a format to it
        for format in FormatContext.AllCases {
            let test = HtmlTest.forFormatting("This is a start.", style: .P, format: format, startingAt: 5, endingAt: 7)
            let expectation = XCTestExpectation(description: "Format \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == test.startHtml)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == test.endHtml)
                                expectation.fulfill()
                            }
                        }
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoFormats() throws {
        // Select a range in a P styled string, apply a format to it, and then undo
        for format in FormatContext.AllCases {
            let test = HtmlTest.forFormatting("This is a start.", style: .P, format: format, startingAt: 5, endingAt: 7)
            let expectation = XCTestExpectation(description: "Undo formatting of \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == test.startHtml)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == test.endHtml)
                                self.webView.testUndo() {
                                    self.webView.getHtml { unformatted in
                                        XCTAssert(unformatted == test.startHtml)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUnformats() throws {
        // Given a range of formatted text, toggle the format off
        for format in FormatContext.AllCases {
            let test = HtmlTest.forUnformatting("This is a start.", style: .P, format: format, startingAt: 5, endingAt: 7)
            let expectation = XCTestExpectation(description: "Format \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == test.startHtml)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == test.endHtml)
                                expectation.fulfill()
                            }
                        }
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoUnformats() throws {
        // Given a range of formatted text, toggle the format off, then undo
        for format in FormatContext.AllCases {
            let rawString = "This is a start."
            let test = HtmlTest.forUnformatting(rawString, style: .P, format: format, startingAt: 5, endingAt: 7)
            // The undo doesn't preserve the id that is injected by .forUnformatting, so construct startHTML
            // below for comparison post-undo.
            let formattedString = rawString.formattedHtml(adding: format, startingAt: 5, endingAt: 7, withId: nil)
            let startHtml = formattedString.styledHtml(adding: .P)
            let expectation = XCTestExpectation(description: "Format \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == test.startHtml)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == test.endHtml)
                                self.webView.testUndo() {
                                    self.webView.getHtml { unformatted in
                                        XCTAssert(unformatted == startHtml)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testFormatSelections() throws {
        // Select a caret location in a formatted string and make sure getSelection identifies the format properly
        // This is important for the toolbar indication of formatting as the cursor selection changes
        for format in FormatContext.AllCases {
            let rawString = "This is a start."
            let formattedString = rawString.formattedHtml(adding: format, startingAt: 5, endingAt: 7, withId: format.tag)
            let startHtml = formattedString.styledHtml(adding: .P)
            let expectation = XCTestExpectation(description: "Select inside of format \(format.tag)")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == startHtml)
                    self.webView.setTestRange(startId: format.tag, startOffset: 1, endId: format.tag, endOffset: 1) { result in
                        XCTAssert(result)
                        switch format {
                        case .B:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.bold)
                                expectation.fulfill()
                            }
                        case .I:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.italic)
                                expectation.fulfill()
                            }
                        case .U:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.underline)
                                expectation.fulfill()
                            }
                        case .STRIKE:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.strike)
                                expectation.fulfill()
                            }
                        case .SUB:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.sub)
                                expectation.fulfill()
                            }
                        case .SUP:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.sup)
                                expectation.fulfill()
                            }
                        case .CODE:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.code)
                                expectation.fulfill()
                            }
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testMultiElementSelections() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (   // "He|llo " is italic and bold, "world" is bold; unformat italic
                HtmlTest(
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><b id=\"b\">Hello world</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (   // "He|llo " is italic and bold, "world" is bold; unformat bold
                HtmlTest(
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><i id=\"i\">Hello </i>world</p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (   // "world" is italic, select "|Hello <i>world</i>|" and format bold
                HtmlTest(
                    startHtml: "<p id=\"p\">Hello <i id=\"i\">world</i></p>",
                    endHtml: "<p id=\"p\"><b>Hello <i id=\"i\">world</i></b></p>",
                    startId: "p",
                    startOffset: 0,
                    endId: "i",
                    endOffset: 5
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (   // "Hello " is italic and bold, "wo|rld" is bold; unformat bold
                HtmlTest(
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><i id=\"i\">Hello </i>world</p>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (   // "He|llo " is italic and bold, "world" is bold; unformat bold
                HtmlTest(
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><i id=\"i\">Hello </i>world</p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Unformatting nested tags")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == startHtml)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == endHtml, "Expected \(endHtml), saw: \(formatted ?? "nil")")
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testBlockQuotes() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (   // Increase quote level, selection in text element
                HtmlTest(
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<blockquote><p id=\"p\">Hello <b id=\"b\">world</b></p></blockquote>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.increaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            (   // Increase quote level, selection in a non-text element
                HtmlTest(
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.increaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            (   // Decrease quote level from 1 to 0, selection in a non-text element, no styling
                HtmlTest(
                    startHtml: "<blockquote><b id=\"b\"><i id=\"i\">Hello </i>world</b></blockquote>",
                    endHtml: "<b id=\"b\"><i id=\"i\">Hello </i>world</b>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.decreaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            (   // Decrease quote level from 1 to 0, selection in a non-text element, with styling
                HtmlTest(
                    startHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    endHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.decreaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            (   // Decrease quote level from 2 to 1, selection in a non-text element
                HtmlTest(
                    startHtml: "<blockquote><blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote></blockquote>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.decreaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            (   // Increase quote level in an embedded paragraph in a blockquote, selection in a non-text element
                HtmlTest(
                    startHtml:  "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote>",
                    endHtml:    "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><blockquote><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote></blockquote>",
                    startId: "i2",
                    startOffset: 2,
                    endId: "i2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.increaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Increasing and decreasing block levels")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == startHtml, "Expected start: \(startHtml), saw: \(contents ?? "nil")")
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == endHtml, "Expected end: \(endHtml), saw: \(formatted ?? "nil")")
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoBlockQuotes() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (   // Increase quote level, selection in text element
                HtmlTest(
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<blockquote><p id=\"p\">Hello <b id=\"b\">world</b></p></blockquote>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.increaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            (   // Increase quote level, selection in a non-text element
                HtmlTest(
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.increaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            (   // Decrease quote level from 1 to 0, selection in a non-text element, no styling
                HtmlTest(
                    startHtml: "<blockquote><b id=\"b\"><i id=\"i\">Hello </i>world</b></blockquote>",
                    endHtml: "<b id=\"b\"><i id=\"i\">Hello </i>world</b>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.decreaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            (   // Decrease quote level from 1 to 0, selection in a non-text element, with styling
                HtmlTest(
                    startHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    endHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.decreaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            (   // Decrease quote level from 2 to 1, selection in a non-text element
                HtmlTest(
                    startHtml: "<blockquote><blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote></blockquote>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.decreaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            (   // Increase quote level in an embedded paragraph in a blockquote, selection in a non-text element
                HtmlTest(
                    startHtml:  "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote>",
                    endHtml:    "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><blockquote><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote></blockquote>",
                    startId: "i2",
                    startOffset: 2,
                    endId: "i2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.increaseQuoteLevel() {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Increasing and decreasing block levels")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == startHtml, "Expected start: \(startHtml), saw: \(contents ?? "nil")")
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == endHtml, "Expected end: \(endHtml), saw: \(formatted ?? "nil")")
                                self.webView.testUndo() {
                                    self.webView.getHtml { unformatted in
                                        XCTAssert(formatted == endHtml, "Expected start: \(startHtml), saw: \(unformatted ?? "nil")")
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testLists() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (   // Make a paragraph into an ordered list
                HtmlTest(
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (   // Make a paragraph into an unordered list
                HtmlTest(
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (   // Remove a list item from a single-element unordered list, thereby removing the list, too
                HtmlTest(
                    startHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (   // Remove a list item from a single-element ordered list, thereby removing the list, too
                HtmlTest(
                    startHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (   // Remove a list item from a multi-element unordered list, leaving the list in place
                HtmlTest(
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ul><p>Hello <b id=\"b\">world1</b></p><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (   // Change one of the list items in a multi-element unordered list to an ordered list item
                HtmlTest(
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ol><li><p>Hello <b id=\"b\">world1</b></p></li></ol><ul><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == startHtml, "Expected start: \(startHtml), saw: \(contents ?? "nil")")
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == endHtml, "Expected end: \(endHtml), saw: \(formatted ?? "nil")")
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoLists() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (   // Make a paragraph into an ordered list
                HtmlTest(
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (   // Make a paragraph into an unordered list
                HtmlTest(
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (   // Remove a list item from a single-element unordered list, thereby removing the list, too
                HtmlTest(
                    startHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (   // Remove a list item from a single-element ordered list, thereby removing the list, too
                HtmlTest(
                    startHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (   // Remove a list item from a multi-element unordered list, leaving the list in place
                HtmlTest(
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ul><p>Hello <b id=\"b\">world1</b></p><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (   // Change one of the list items in a multi-element unordered list to an ordered list item
                HtmlTest(
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ol><li><p>Hello <b id=\"b\">world1</b></p></li></ol><ul><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == startHtml, "Expected start: \(startHtml), saw: \(contents ?? "nil")")
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == endHtml, "Expected end: \(endHtml), saw: \(formatted ?? "nil")")
                                self.webView.testUndo() {
                                    self.webView.getHtml { unformatted in
                                        XCTAssert(unformatted == startHtml, "Expected start: \(startHtml), saw: \(unformatted ?? "nil")")
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testInsertEmpty() throws {
        /*
         From this oldie but goodie... https://bugs.webkit.org/show_bug.cgi?id=15256
         
         For example, given an HTML block like this:

             <div contentEditable="true"><div id="scratchpad"></div></div>

         and code like this:

             document.getElementById("scratchpad").innerHTML = "<div id=\"foo\">blah</div><div id=\"bar\">blah</div>";

             var sel = window.getSelection();
             sel.removeAllRanges();
             var range = document.createRange();

             range.setStartAfter(document.getElementById("foo"));
             range.setEndAfter(document.getElementById("foo"));
             sel.addRange(range);

             document.execCommand("insertHTML", false, "<div id=\"baz\">-</div>");

         One would expect this snippet to result in:

             <div id="foo">blah</div><div id="baz">-</div><div id="bar">blah</div>

         but instead, you get:

             <div id="foo">blah</div><div id="bar">-blah</div>

         I've tried every combination of set{Start|End}{After|Before|} that I can think of, and even things like setBaseAndExtent, modifying the selection object directly by extending it in either direction, etc.  Nothing works.
         Comment 38
         */
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (   // Make a paragraph into an ordered list
                HtmlTest(
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            )
        ]
        for (test, action) in htmlTestAndActions {
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == startHtml, "Expected start: \(startHtml), saw: \(contents ?? "nil")")
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == endHtml, "Expected end: \(endHtml), saw: \(formatted ?? "nil")")
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }
    
    func testUndoInsertEmpty() throws {
        /* See the notes in testInsertEmpty */
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (   // Make a paragraph into an ordered list
                HtmlTest(
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            )
        ]
        for (test, action) in htmlTestAndActions {
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getHtml { contents in
                    XCTAssert(contents == startHtml, "Expected start: \(startHtml), saw: \(contents ?? "nil")")
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getHtml { formatted in
                                XCTAssert(formatted == endHtml, "Expected end: \(endHtml), saw: \(formatted ?? "nil")")
                                self.webView.testUndo() {
                                    self.webView.getHtml { unformatted in
                                        XCTAssert(unformatted == startHtml, "Expected start: \(startHtml), saw: \(formatted ?? "nil")")
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 2)
        }
    }

}
