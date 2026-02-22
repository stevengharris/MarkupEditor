# Change Log

## Version 0.9.0 (Beta 8.0)

This release introduces MacOS support. The MarkupEditor library now builds and tests properly in MacOS in addition to iOS and Mac Catalyst. The SwiftUIDemo now has a MacOS target and is functional. However, the integration with the MacOS menubar and context menu are missing, as is any ability within the demo to create a new file, open an existing one, or to view the underlying HTML. These problems will be present in issues on GitHub to track progress and closure.

* Build library and pass tests on MacOS [Issue 1 (!!!)](https://github.com/stevengharris/MarkupEditor/issues/1).
* Initial pass at demos, [issue](https://github.com/stevengharris/MarkupEditor/issues/261) will be left open.
* Improve test speed by sharing a singleton HtmlTestPage for a test suite, created for the first (serialized) test case in the suite.
* Improve(?) the GitHub actions build/test to include multiple steps, build on MacOS and Mac Catalyst.
* Modify the Package.swift to support the MacOS target and tests. Set platform versions to .iOS(.v17), .macCatalyst(.v17), .macOS(.v14)

## Version 0.8.7 (Beta 7.4.1)

This was a minor release to sync with a newer version of markupeditor-base and tofix a hotkey crash when using CTRL-B, I, etc.

## Version 0.8.6 (Beta 7.4)

This release replaces the old MarkupEditor XCTest-based `BasicTests` with two new Swift Testing targets. The first, `BaseTests`, uses the test data from markupeditor-base to drive 22 new Swift Testing suites comprising a total of 226 tests. Sharing the test data between markupeditor-base and the Swift MarkupEditor is a significant milestone to ensuring they remain in sync and that changes in the base project don't introduce regressions in the Swift version. The second target, `SwiftTests`, although currently consisting of a single test, is meant to contain all tests that are specific to the Swift version of the MarkupEditor. The suite currently tests that pasting of an image results in a local file in the document directory, an operation not supported in markupeditor-base, but which was part of `BasicTests` before.

* Extract existing test data from the Swift MarkupEditor XCTest cases into JSON files for use in [markupeditor-base](https://github.com/stevengharris/markupeditor-base). Those data files are now used to drive JEST-based testing in markupeditor-base, per https://github.com/stevengharris/markupeditor-base/issues/6 and are included in markupeditor-base `package.json` `files`.
* Augment `prepare.sh` script to copy JSON test data files that are installed in the markupeditor-js directory.
* Implement HtmlTestSuite to load markupeditor-base JSON test suites, populate an array of HtmlTests. Update old `HtmlTest.swift` to conform to the changes adopted in markupeditor-base and sharing a `run` method for parameterized testing.
* Adopt Swift Testing framework, using parameterized tests to iterate over the JSON data. Move (only) the test targets to iOS 16.
* Move remaining Swift MarkupEditor specific tests (PasteImage) into a new `SwiftTests` target.
* Adjust `swift.yml` for GitHub Actions, moving `runs-on` to `macos-15`.

## Version 0.8.5 (Beta 7.3)

This release formalizes the usage of a separate repository - [markupeditor-base](https://github.com/stevengharris/markupeditor-base) - for all the underlying JavaScript code in the Swift MarkupEditor. There should be no compatibility issues introduced at a Swift level. However, the project structure has been changed to accommodate this underlying change. The markupeditor-base project includes a [web site](https://stevengharris.github.io/markupeditor-base/), [demo](https://stevengharris.github.io/markupeditor-base/demo/index.html) and a [Developer's Guide](https://stevengharris.github.io/markupeditor-base/guide/index.html). The Developer's Guide has much more information than previously existed on the topic of embedding the JavaScript-based WYSIWYG editing capability into an application environment, one of which is Swift.

* Move previous History section of the README to this CHANGELOG.md.
* Eliminate previous `rollup` directory under Swift MarkupEditor source control and replace with a new markupeditor-js directory that is an npm project with a markupeditor-base dependency. See the writup in `markupeditor-js/README.ms`.
* Eliminate the previous READMEJS.md and replace it with the writup in `markupeditor-js/README.ms`.
* Use a new script in `markup.html` to instantiate a MarkupEditor instance and use the markupeditor-base `ToolbarConfig`.
* Adopt changes to markup.css and mirror.css as driven from markupeditor-base.

## Version 0.8.4 (Beta 7.2)

* Add `userResourceFiles` to MarkupWKWebViewConfiguration to be able to identify resources from the app bundle to co-locate with the document being edited See [Issue 229](https://github.com/stevengharris/MarkupEditor/issues/229). The README section on [Customizing the MarkupEditor](#customizing-the-markupeditor) and the demos have been updated to reflect this change.
* Fix callback to `this.imageAdded` when an error is encountered loading an image.
* [FIXED] [Code blocks should be horizontally scrollable](https://github.com/stevengharris/MarkupEditor/issues/231)

## Version 0.8.3 (Beta 7.1)

* Created an initial writeup of how to work with JavaScript code in MarkupEditor, called [READMEJS](https://github.com/stevengharris/MarkupEditor/blob/main/READMEJS.md). The writeup includes information about the build process and requirements, key files, as well as debugging tips.
* [FIXED] For documents with [multiple content-editable divs](https://github.com/stevengharris/MarkupEditor/discussions/178), it was possible to select across divs, which thereby allowed deletion and editing operations for multiple divs at once. This version prevents selection across divs.
* [FIXED] Remove Xcode project references to the now-deleted UndoTests and RedoTests.
* [FIXED] [Multi-selection in lists doesn't work properly](https://github.com/stevengharris/MarkupEditor/issues/219)
* [FIXED] [Search mode background indication](https://github.com/stevengharris/MarkupEditor/issues/223)

## Version 0.8.0 (Beta 7)

This release is a very big change under the covers but should remain (almost completely) compatible with previous versions. The big change consists of replacing the MarkupEditor's custom DOM manipulation code in `markup.js` with code that uses [ProseMirror](https://prosemirror.net). ProseMirror is a JavaScript "toolkit for building rich-text editors." Instead of writing JavaScript code to manipulate the `contenteditable` DOM directly, the MarkupEditor now uses ProseMirror APIs to apply transactional changes to the ProseMirror `EditorState` which in turn modifies the DOM shown in the MarkupWKWebView. I'll be writing more about ProseMirror and how it is used by the MarkupEditor separately, but this entry in the README serves as a notification of the change.

* Compatibility and Customization
    * There are effectively no changes to the MarkupEditor API on the Swift side. Your existing custom implementations of MarkupDelegate methods should continue to work. Existing applications that use the MarkupEditor without modification should work without any issues. Existing usage of custom user css and scripts should work without issues *unless your script is manipulating the DOM directly*.
    * Any customizations of `markup.css` or `markup.html` will need to be compared to the new versions and merged properly.
    * If you forked `markup.js`, then you will need to adapt those changes to the new ProseMirror approach present in the new `markup.js`. **NOTE:** The `Resources/markup.js` file that is now loaded by the MarkupEditor is a build artifact created using [rollup](https://rollupjs.org) and __should not be edited directly__ except for transient debugging purposes. See [READMEJS](https://github.com/stevengharris/MarkupEditor/blob/main/READMEJS.md) about the MarkupEditor build and how that is integrated with ProseMirror modules. 
    * Some public methods of `markup.js` that are invoked using `evaluateJavaScript` in the MarkupWKWebView have been deprecated or changed, but their public signatures in MarkupWKWebView have not changed or have been extended in a compatible manner if needed.
    * Custom scripts that attempt to modify the DOM directly will not work in the new ProseMirror-based world. DOM manipulation is available only through the exported functions of `markup.js`. If you need to work at this level, you will require a full development setup per [READMEJS](https://github.com/stevengharris/MarkupEditor/blob/main/READMEJS.md). The README section on [Customizing the MarkupEditor](#customizing-the-markupeditor) and the example code has been updated to reflect this change.
* Change `StyledContentView` and `StyledViewController` to `CustomContentView` and `CustomViewController` to reflect the limitations on direct modification of the DOM in user scripts, as discussed in [Customizing the MarkupEditor](#customizing-the-markupeditor). Update `custom.js` and `custom.css` used in those demos.
* Update the README to reflect the adoption of ProseMirror in MarkupEditor. The README does not discuss the changes from the previous non-ProseMirror version. There is some limited context provided in [Legacy and Acknowledgements](#legacy-and-acknowledgements).
* Support new *Code* paragraph style in addition to the existing *P* and *H1-H6*. The new style shows up in the MarkupToolbar by default. This was a [longstanding issue](https://github.com/stevengharris/MarkupEditor/issues/96) but was very simple to fix with ProseMirror.
* Use `<EM>` rather than `<I>` and `<STRONG>` rather than `<B>` in HTML output. The MarkupEditor still accepts HTML with `<I>` and `<B>` tags in `setHtml`, but will only produce HTML (via `getHtml`) that contains `<EM>` and `<STRONG>`. This was done to adhere to ProseMirror's defaults, but is "more correct" from an HTML perspective. Since any existing documents produced using the MarkupEditor will contain `<B>` and `<I>`, but they load and display properly into the new version, the change results in a kind of lazy update, where it only affects new documents or old ones that you make changes to.
* Remove the use of `<TBODY>` and `<THEAD>`, since `<TD>` and `<TH>` properly define the header and body elements. The MarkupEditor still accepts HTML with `<TBODY>` and `<THEAD>` tags in `setHtml`, but will not produce HTML (via `getHtml`) that contains them. Since any existing tables produced using the MarkupEditor will contain `<TBODY>` and perhaps `<THEAD>`, but they load and display properly into the new version, the change results in a kind of lazy update, where it only affects new documents or old ones that you make changes to.
* Slight editing behavior change for formatting (e.g., bold, italic, etc). In the original MarkupEditor version, if you selected any point within a word and formatted (e.g., CTRL-B), the word would be changed to the new format. In this new version, you must select the word (e.g., by double-clicking on it) before changing or setting the format. The previous approach resulted in ambiguous situations, particularly when the cursor was at the beginning or end of a word. For example, if you want to begin typing in a non-bolded font at the end of a bolded word, and you press CTRL-B, does your gesture mean you intend to unbold the word before the cursor or just stop using bold when you type?
* Some "multi-selection" editing behaviors, where the selection begins in one element and ends in another, may be slightly different. I don't think any of these changes will be noticeable, and the tests cover a broad range of conditions, each of which I have reviewed and decided are correct from a principal of least astonishment perspective.
* Remove UndoTests and RedoTests, adopting an approach in BasicTests that exercises undo and redo for every action. These new tests also verify that the selection is set properly after every action and the undo/redo of that action. The BasicTests suite is faster than before, even including undo and redo.
* Add a separate [License](#license) section to point out ProseMirror usage under MIT License.
* [FIXED] [The issue of keyboard hiding when manipulating headers](https://github.com/stevengharris/MarkupEditor/issues/214)
* [FIXED] [Table navigation with Enter](https://github.com/stevengharris/MarkupEditor/issues/209)
* [FIXED] [Add parameter in getHtml function to remove css classes](https://github.com/stevengharris/MarkupEditor/issues/200)
* [FIXED] [Trouble placing an image at the top of the editor](https://github.com/stevengharris/MarkupEditor/issues/196)
* [FIXED] [The styling('Bold', 'cursive') is reset with each new line.(After enter is pressed)](https://github.com/stevengharris/MarkupEditor/issues/194)
* [FIXED] [Pasting trouble](https://github.com/stevengharris/MarkupEditor/issues/175)
* [FIXED] [Keyboard dismissing when I select the "Bold" option from tool bar](https://github.com/stevengharris/MarkupEditor/issues/159)
* [FIXED] [Support line breaks](https://github.com/stevengharris/MarkupEditor/issues/135)
* [FIXED] [Treatment of \<code> blocks](https://github.com/stevengharris/MarkupEditor/issues/96)

## Version 0.7.2 (Beta 6)

* Search improvements, including:
  * When in search mode, interpret Enter as "search forward" and Shift+Enter as "search backward".
  * Outline the selection while in search mode with a border, so it's clearer where you are in the document.
  * Slightly darken background while in search mode, to indicate visually that Enter and Shift+Enter are being interpreted as search forward and backward.
  * Highlight all strings matching the search string, so you can see where Enter and Shift+Enter will move next. Note that highlighting, which depends on the CSS custom highlight API (ref: https://developer.mozilla.org/en-US/docs/Web/API/CSS_Custom_Highlight_API) only works in Safari 17.2 or later, which won't be available in older runtimes still supported by the MarkupEditor.
  * Add MarkupDelegate callbacks `markupActivateSearch` and `markupDeactivateSearch`, default behavior for which is to toggle `MarkupEditor.searchActive` state so the MarkupToolbar can be disabled/enabled while in search mode.
  * Limit search to contenteditable divs (generally there is only one, `MU.editor`).
* When using multiple contenteditable DIVs, gate blur event from resetting `selectedID` by `muteFocusBlur`.
  
## Version 0.7.1 (Beta 5)

* Support multiple editable areas in a single document (https://github.com/stevengharris/MarkupEditor/pull/195). There is a very small SwiftUI-only demo (see DivsContentView in the SwiftUIDemo) of the capability, but the feature is as-yet undocumented. See the [discussion](https://github.com/stevengharris/MarkupEditor/discussions/178) for some more detail.
* Allow users to select which list types to support (https://github.com/stevengharris/MarkupEditor/pull/197). Thanks [Thomas Mengelatte](https://github.com/ThomasMengelatte).

## Version 0.7.0 (Beta 4)

The main change in this version is to adopt strict concurrency in anticipation of Swift 6. You may have to make source code changes to use this version. Specifically, the `MarkupEditor` class, whose statics contain settings and defaults is now marked `@MainActor`. If you access `MarkupEditor` from a class that is itself not main-actor-isolated, perhaps in a method that sets MarkupEditor defaults like this:

```
private static func initializeMarkupEditor() {
    MarkupEditor.style = .compact
    MarkupEditor.allowLocalImages = true
    MarkupEditor.toolbarLocation = .keyboard
    #if DEBUG
    MarkupEditor.isInspectable = true
    #endif
}
```

then you will see errors like:

```
Main actor-isolated static property 'style' can not be mutated from a non-isolated context
```

You can fix the errors by making the method accessing the `MarkupEditor` class main actor-isolated like this:

```
@MainActor
private static func initializeMarkupEditor() {
    MarkupEditor.style = .compact
    MarkupEditor.allowLocalImages = true
    MarkupEditor.toolbarLocation = .keyboard
    #if DEBUG
    MarkupEditor.isInspectable = true
    #endif
}
```

* Enforce strict concurrency, update to @MainActor in various places (https://github.com/stevengharris/MarkupEditor/issues/193)
* Expose public MarkupWKWebView.baseUrl (per https://github.com/stevengharris/MarkupEditor/issues/175#issuecomment-1900884682)

## Version 0.6.2 (Beta 3)

* Update README to clarify how to get modified HTML, a recurring issue for users (e.g., https://github.com/stevengharris/MarkupEditor/issues/176).
* Update README to include a [Customizing the MarkupEditor](#customizing-the-markupeditor) section.
* Add ability to customize [CSS](#customizing-document-style) and [scripts](#adding-custom-scripts) in MarkupWKWebViewConfiguration.
* Fixed various paste issues (https://github.com/stevengharris/MarkupEditor/issues/184, https://github.com/stevengharris/MarkupEditor/issues/179, https://github.com/stevengharris/MarkupEditor/issues/128).
* Removed empty text element left on formatting (https://github.com/stevengharris/MarkupEditor/issues/181).

## Version 0.6.0 (Beta 2)

There have been a lot of changes since Beta 1 was released. Beta 2 pulls them all together in what I hope is closer to a proper release candidate.

## Features

* The MarkupEditor did not support text search, but now does. See [Search](#search) in this README.
* There was no way to provide "placeholder" text for an empty MarkupWKWebView, but it is now supported.  (https://github.com/stevengharris/MarkupEditor/issues/101)
* Setting the selection when the MarkupWKWebView is opened (which updates the MarkupToolbar) was automatic but is now optional. (https://github.com/stevengharris/MarkupEditor/issues/70)

## Closed Issues

* Enter and multi-element styling operations were broken inside of indents. (https://github.com/stevengharris/MarkupEditor/issues/57)
* Local images did not respect the resourcesUrl setting relative to the base URL. (https://github.com/stevengharris/MarkupEditor/issues/59)
* Image sizing was absolute, which caused problems moving between devices, but display is now limited to the width of the device/window. (https://github.com/stevengharris/MarkupEditor/issues/69)
* Editing *only on Intel-based Mac Catalyst apps on MacOS 13 Ventura* was buggy/broken due to a base WKWebView regression that Apple fixed in MacOS 14 Sonoma. (https://github.com/stevengharris/MarkupEditor/issues/76)
* Paste alerts (e.g., "... would like to paste from ...") were being presented unnecessarily. (https://github.com/stevengharris/MarkupEditor/issues/77)
* Link URLs were being inserted at the incorrect selection point. (https://github.com/stevengharris/MarkupEditor/issues/79)
* The selection caret was missing sometimes when the MarkupWKWebView was opened. (https://github.com/stevengharris/MarkupEditor/issues/83)
* Spurious notifications of content changes were issued when images were prepped to be resizable. (https://github.com/stevengharris/MarkupEditor/issues/86)
* Editing on touch devices had various issues. (https://github.com/stevengharris/MarkupEditor/issues/89, https://github.com/stevengharris/MarkupEditor/issues/93, https://github.com/stevengharris/MarkupEditor/issues/106)
* Pasting content with newlines (e.g., from the Notes app) was buggy. (https://github.com/stevengharris/MarkupEditor/issues/128)
* The TableSizer drag operation would not produce a table properly on Mac Catalyst. (https://github.com/stevengharris/MarkupEditor/issues/142)
* There was a white flash when the MarkupWKWebView was presented initially in dark mode. (https://github.com/stevengharris/MarkupEditor/issues/143)
* A change introduced to fix the responsive area on touch devices resulted in an incorrect scroll height. (https://github.com/stevengharris/MarkupEditor/issues/144)
* The hot-key combo to use the `code` style was cumbersome and was changed from ⌘{ to ⌘\`. (https://github.com/stevengharris/MarkupEditor/issues/148)

## Version 0.5.1 (Beta 1)

Fix a tagging issue for the Swift package.

## Version 0.5.0 (Beta 1)

This is the first Beta release for the MarkupEditor! Please see [the announcement and discussion](https://github.com/stevengharris/MarkupEditor/discussions/52) about it.

### Closed Issues

* Replace LinkToolbar and ImageToolbar with popovers ([Issue 42](https://github.com/stevengharris/MarkupEditor/issues/42))
* Build from package is broken on iOS ([Issue 47](https://github.com/stevengharris/MarkupEditor/issues/47))
* Touch device selection doesn't work properly ([Issue 48](https://github.com/stevengharris/MarkupEditor/issues/48))
* Make paragraph style an optional part of StyleToolbar ([Issue 49](https://github.com/stevengharris/MarkupEditor/issues/49))

## Version 0.4.0

I consider this release to be feature complete with the exception of some remaining UX problems on touch devices. If you were consuming earlier versions, you may encounter breaking changes, but I wanted to get those done before Beta. For example, the MarkupWebView previously was a UIViewRepresentable of the MarkupWKWebView. It has been eliminated in favor of a SwiftUI MarkupEditorView and a separate MarkupWKWebViewRepresentable.

The major drivers of the pre-Beta work have been usability and proper support for touch devices. This release also completely eliminates any need for a user to know about the SubToolbar, which previous versions surfaced because of the need to overlay it on the MarkupWKWebView. This release includes a new MarkupEditorView and MarkupEditorUIView for SwiftUI and UIKit respectively. These Views/UIViews lay out and manage the MarkupToolbar and (new) MarkupToolbarUIView, providing a simpler end-user experience when you just want to drop in a View/UIView. There are lots of other improvements and features as outlined below.

### Closed Issues

* Multi-indent/outdent operations work ([Issue 13](https://github.com/stevengharris/MarkupEditor/issues/13))
* Easy image resizing ([Issue 14](https://github.com/stevengharris/MarkupEditor/issues/14)) [pinch gesture support underway now]
* Table sizer works on touch devices ([Issue 15](https://github.com/stevengharris/MarkupEditor/issues/15))
* User settable table bordering ([Issue 16](https://github.com/stevengharris/MarkupEditor/issues/16))
* Complete menu/hotkey support that syncs with the ToolbarContents ([Issue 17](https://github.com/stevengharris/MarkupEditor/issues/17))
* Toolbar visible selection state works properly for large selections ([Issue 18](https://github.com/stevengharris/MarkupEditor/issues/18))
* Pasting HTML works properly ([Issue 20](https://github.com/stevengharris/MarkupEditor/issues/20))
* Enter at end of indent outdents until no longer indented ([Issue 21](https://github.com/stevengharris/MarkupEditor/issues/21))
* Block quote outdent works on one line at a time ([Issue 22](https://github.com/stevengharris/MarkupEditor/issues/22))
* Easily customizable toolbar contents using ToolbarContents ([Issue 31](https://github.com/stevengharris/MarkupEditor/issues/31))
* Support pinch gesture for image resizing ([Issue 38](https://github.com/stevengharris/MarkupEditor/issues/38))
* InputAccessoryView disappears on device rotation ([Issue 39](https://github.com/stevengharris/MarkupEditor/issues/39))
* Provide context menus (copy/cut/paste) ([Issue 45](https://github.com/stevengharris/MarkupEditor/issues/45))

### Usability

* MarkupEditor struct provides central access to configuration/customization
* MarkupEditorView sets up and manages the MarkupToolbar automatically for SwiftUI development
* MarkupEditorUIView set up and managed MarkupToolbarUIView automatically for UIKit development
* MarkupWKWebView automatically installs a customized MarkupToolbarUIView as the inputAccessoryView
* Eliminate need for users to set up EnvironmentObjects to use the MarkupEditor as in previous versions

## Version 0.3.3

* Run build and tests on main using GitHub actions.
* Start using the GitHub issue tracker and PRs to monitor issues prior to Beta.
* Support multi-list operations.
* Support multi-indent/outdent operations.

## Version 0.3.2

This is an intermediate release in support of multi-element operations. A multi-element operation involves selecting multiple elements (e.g., paragraphs or formatted text elements - basically a large selected area in the document) and applying an operation like changing styles, formatting (e.g., bold, italic), or list attributes.

* Support multi-style operations.
* Support multi-format operations.

## Version 0.3.1

This version is getting closer feature-complete on Mac Catalyst. There have been some API changes from the 0.2 version, primarily driven by the new support for local images.

* Support local images in the edited document, the ability to insert an image from file as opposed to an external URL.
* Refactor tests into BasicTests, UndoTests, and RedoTests. Tests have no dependency on a host app.
* All operations support undo/redo properly (with the exception of selections across paragraphs, as cited in Known Issues).
* Support pasting HTML and images. (Previously only plain text was supported.)
* Menus work in the demos but are still incomplete.
* List editing responds properly to the Enter key at beginning, inside, and end of list items. Enter in an empty list item outdents until exiting the list.
* Tab is now strictly a table navigation mechanism and is no longer associated with indent/outdent operations.

## Version 0.2.2

The labeled toolbar took up too much screen real estate in my other project, so I created a .compact form and made that selectable via ToolbarPreference. Now I have a way to add other preferences easily. I also needed a better way to communicate the selectionState and selectedWebView when I have an arbitrary number of MarkupWebViews being editing using a single MarkupToolbar. I set up MarkupEnv to accomplish that and adjusted the SwiftUIDemo and UIKitDemo to use it.

* Add this History section to the README.
* Make the toolbar configurable between .compact (the new default) and .labeled via ToolbarPreference.
* Use MarkupEnv to access the selectionState and selectedWebView.
* Bundle loading logic now depends on SWIFT_PACKAGE in MarkupWKWebView, not my homegrown USEFRAMEWORK setting.
* Some minor adjustments to backgrounds and css to fix issues when the MarkupToolbar and MarkupWebView were embedded in other SwiftUI views.

## Version 0.2.1

* This was the first version made public and open sourced.
