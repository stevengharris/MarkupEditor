//
//  HtmlTest.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 4/6/22.
//

import Foundation
import MarkupEditor
import Testing

/// An HtmlTest embeds markers for the selection point(s) in the `startHtml`. The selection to/from are identified using `sel`.
/// On the JavaScript side, these markers are removed and the corresponding selection is set. The actual HTML that is tested and returned
/// from the test will not contain the embedded `sel` markers, so endHtml and undoHtml, if set, should not embed such markers.
///
/// The JSON file for each suite also contains `action` items for each test, which produces a function in JavaScript using the
/// Function constructor. Since we can't do that in Swift, we specify the `action` var as an async function, and then in each
/// test, we get the `action` for each test held onto by the suite. Occasionally (e.g., in `baseline`), no action is needed). Here we also
/// use `stringAction` in the case where the action returns a `String`. In JavaScript, we can just test if the return is null, but in
/// Swift we have to type the return properly, and all of the existing MU methods execute a handler with argument if needed.
final public class HtmlTest: Codable, Sendable, CustomStringConvertible, CustomTestStringConvertible {
    public static let timeout: Double = 100     // Needs to be large for GitHub actions
    public let description: String
    public let skipTest: String?
    public let skipSet: Bool
    public let skipUndoRedo: Bool
    public let sel: String
    public let startHtml: String
    public let endHtml: String
    public let undoHtml: String
    public let pasteString: String?
    
    public var testDescription: String {description}
    
    enum CodingKeys: String, CodingKey {
        case description = "description"
        case skipTest = "skipTest"
        case skipSet = "skipSet"
        case skipUndoRedo = "skipUndoRedo"
        case sel = "sel"
        case startHtml = "startHtml"
        case endHtml = "endHtml"
        case undoHtml = "undoHtml"
        case pasteString = "pasteString"
    }

    public init(
        description: String,
        skipTest: String? = nil,
        skipSet: Bool = false,
        skipUndoRedo: Bool = false,
        sel: String = "|",
        startHtml: String,
        endHtml: String? = nil,
        undoHtml: String? = nil,
        pasteString: String? = nil
    ) {
        self.skipTest = skipTest
        self.description = skipTest == nil ? description : "SKIPPED... \(description)"
        self.skipSet = skipSet
        self.skipUndoRedo = skipUndoRedo
        self.sel = sel
        self.startHtml = startHtml
        self.endHtml = endHtml ?? startHtml
        self.undoHtml = undoHtml ?? startHtml
        self.pasteString = pasteString
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        skipTest = try values.decodeIfPresent(String.self, forKey: .skipTest)
        let desc = try values.decode(String.self, forKey: .description)
        description = skipTest == nil ? desc : "SKIPPED... \(desc)"
        skipSet = try values.decodeIfPresent(Bool.self, forKey: .skipSet) ?? false
        skipUndoRedo = try values.decodeIfPresent(Bool.self, forKey: .skipUndoRedo) ?? false
        sel = try values.decodeIfPresent(String.self, forKey: .sel) ?? "|"
        startHtml = try values.decode(String.self, forKey: .startHtml)
        endHtml = try values.decodeIfPresent(String.self, forKey: .endHtml) ?? startHtml
        undoHtml = try values.decodeIfPresent(String.self, forKey: .undoHtml) ?? startHtml
        pasteString = try values.decodeIfPresent(String.self, forKey: .pasteString)
    }
    
    public func run(action: ((_: MarkupWKWebView) async throws -> Void)?, in view: MarkupWKWebView) async {
        // The `description` of skipped tests is modified to flag them, but
        // by simply returning, they will show up as successful tests.
        if skipTest != nil { return }
        // In some cases (e.g., checking HTML and text preprocessing), we don't
        // want to set the initial HTML.
        if !skipSet {
            let html = await view.setTestHtml(startHtml, sel: sel)
            #expect(html == startHtml)
        }
        // Execute either the `action` or `stringAction` if one if defined,
        // and make sure it produces `endHtml`.
        if let action {
            do {
                try await action(view)
            } catch {
                print("Error: \(error)")
                return
            }
            let html = await view.getTestHtml(sel: sel)
            #expect(html == endHtml)
        }
        // If not skipping the undo/redo step, then to each one, comparing
        // the result with `undoHtml` and `endHtml` respectively. The `undoHtml`
        // is the same as `startHtml` unless otherwise specified.
        if (action != nil && !skipUndoRedo) {
            await view.undo()
            let undoResult = await view.getTestHtml(sel: sel)
            #expect(undoResult == undoHtml)
            await view.redo()
            let redoResult = await view.getTestHtml(sel: sel)
            #expect(redoResult == endHtml)
        }
    }
    
    public func run(stringAction: ((_: MarkupWKWebView) async throws -> String?), in view: MarkupWKWebView) async {
        // The `description` of skipped tests is modified to flag them, but
        // by simply returning, they will show up as successful tests.
        if skipTest != nil { return }
        // In some cases (e.g., checking HTML and text preprocessing), we don't
        // want to set the initial HTML.
        if !skipSet {
            let html = await view.setTestHtml(startHtml, sel: sel)
            #expect(html == startHtml)
        }
        let html: String?
        do {
            html = try await stringAction(view)
        } catch {
            print("Error: \(error)")
            return
        }
        #expect(html == endHtml)
        // If not skipping the undo/redo step, then to each one, comparing
        // the result with `undoHtml` and `endHtml` respectively. The `undoHtml`
        // is the same as `startHtml` unless otherwise specified.
        if (!skipUndoRedo) {
            await view.undo()
            let undoResult = await view.getTestHtml(sel: sel)
            #expect(undoResult == undoHtml)
            await view.redo()
            let redoResult = await view.getTestHtml(sel: sel)
            #expect(redoResult == endHtml)
        }
    }
    
}
