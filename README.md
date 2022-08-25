<p align="center">
    <img src="https://github.com/stevengharris/MarkupEditor/actions/workflows/swift.yml/badge.svg">
    <img src="https://img.shields.io/badge/Swift-5.5-blue.svg">
    <img src="https://img.shields.io/badge/iOS-14.5+-blue.svg" alt="iOS 14.5+">
    <img src="https://img.shields.io/badge/MacCatalyst-14.5-blue" alt="MacCatalyst 14.5+">
    <a href="https://twitter.com/stevengharris">
        <img src="https://img.shields.io/badge/Contact-@stevengharris-lightgrey.svg?style=flat" alt="Twitter: @stevengharris">
    </a>
</p>

# MarkupEditor

### 

WYSIWYG editing for SwiftUI and UIKit apps.

Jealous of those JavaScript coders with their WYSIWYG text editors, but just can't stomach the idea of immersing yourself in JavaScript when you're enjoying the comfort and joy of Swift? Yeah, me too. So when I was forced to do it, I thought I'd share what I did as a way to help others avoid it.

## Demo

![MarkupEditor](https://user-images.githubusercontent.com/1020361/125365436-17f49000-e329-11eb-98f2-1c509acade8a.mp4)

## MarkupEditor Goals and Non-Goals

I am working on a larger project that requires embedded support for "rich text" editing. WYSIWYG editing is a must-have requirement for me. I could have forced my developer-users to use Markdown, but I find it to be annoying both to write and to look at while writing. Who wants to have to mentally filter all that cruft on the screen? Sure, it's a lot better than editing raw HTML; but come on, this is the 21st century. Having to deal with an editing experience where you use some kind of "preview mode" to make sure that what you are writing will be presented like you expect feels like CI/CD for writing. 

Still, I wanted an editing experience that didn't get in the way. I wanted something with the feature-simplicity of Markdown, but presented in a clean, what-you-see-is-what-you-get manner that supported the basics people expect:

1. Styling
    * Present a paragraph or header with a predefined font size
    * Bulleted and numbered lists
    * Indenting and outdenting of text
2. Formatting
    * Bold, italic, underline, code, strikethrough, sub- and super-scripting
3. Embedding
    * Images
    * Tables
    * Links

As you might expect, then, this feature set is pretty darned close to Markdown - or at least a GitHub flavor of Markdown. And as soon as you do WYSIWYG editing, you must support undo/redo properly. The feature list doesn't include some things you might expect from your favorite word processor:

* Colored text
* Highlighting
* Font size changes (except as implied by identifying something as a paragraph or header)

If you want a richer feature set, you can extend the MarkupEditor yourself. The demos include examples of how to extend the MarkupEditor's core features and how to interact with the file system for selecting what to edit. It's my intent to keep the core MarkupEditor feature set to be similar to what you will see in GitHub Markdown.

### What is WYSIWYG, Really?

The MarkupEditor is presenting an HTML document to you as you edit. It uses JavaScript to change the underlying DOM and calls back into Swift as you interact with the document. The MarkupEditor does not know how to save your document or transform it to some other format. This is something your application that consumes the MarkupEditor will need to do. The MarkupEditor will let your `MarkupDelegate` know as the underlying document changes state, and you can take advantage of those notifications to save and potentially transform the HTML into another form. If you're going to do that, then you should make sure that round-tripping back into HTML also works flawlessly. Otherwise, you are using a "What You See Is Not What You Get" editor, which is both less pronounceable and much less useful to your end users.

## Installing the MarkupEditor

You can install the Swift package into your project, or you can build the MarkupEditor framework yourself and make that a dependency.
 
### Swift Package

Add the `MarkupEditor` package to your Xcode project using File -> Swift Packages -> Add Package Dependency...

### Framework

Clone this repository and build the MarkupFramework target in Xcode. Add the MarkupEditor.framework as a dependency to your project.

## Using the MarkupEditor

Behind the scenes, the MarkupEditor interacts with an HTML document (created in `markup.html`) that uses a single `contentEditable` DIV element to modify the DOM of the document you are editing. It uses a subclass of `WKWebView` - the `MarkupWKWebView` - to make calls to the JavaScript in `markup.js`. In turn, the JavaScript calls back into Swift to let the Swift side know that changes occurred. The callbacks on the Swift side are handled by the `MarkupCoordinator`. The `MarkupCoordinator` is the `WKScriptMessageHandler` for a single  `MarkupWKWebView` and receives all the JavaScript callbacks in `userContentController(_:didReceive:)`.  The `MarkupCoordinator` in turn notifies your `MarkupDelegate` of changes. See `MarkupDelegate.swift` for the full protocol and default implementations. 

That sounds complicated, but it is mostly implementation details you should not need to worry about. Your app will typically use either the `MarkupEditorView` for SwiftUI or the `MarkupEditorUIView` for UIKit. The `MarkupDelegate` protocol is the key mechanism for your app to find out about changes as the user interacts with the document. You will typically let your main SwiftUI ContentView or your UIKit UIViewController be your `MarkupDelegate`. You can customize the behavior of the MarkupEditor using the `MarkupEditor` struct (e.g., `MarkupEditor.toolbarStyle = .compact`).

The `MarkupToolbar` is a convenient, pre-built UI to invoke changes to the document by interacting with the `MarkupWKWebView`. You don't need to use it, but if you do, then the easiest way to set it up is just to let the `MarkupEditorView` or `MarkupEditorUIView` handle it automatically. Your application may require something different with the toolbar than what the `MarkupEditorView` or `MarkupEditorUIView` provides. For example, you might have multiple `MarkupEditorViews` that need to share a single `MarkupToolbar`. In this case, you should specify `MarkupEditor.toolbarPosition = .none`. Then, for SwiftUI, use the `MarkupEditorView` together with the `MarkupToolbar` as standard SwiftUI views, identifying the `MarkupEditor.selectedWebView` by responding to the `markupTookFocus(_:)` callback in your `MarkupDelegate`. For UIKit, you can use the `MarkupEditorUIView` and `MarkupToolbarUIView`. See the code in the `MarkupEditorView` or `MarkupEditorUIView` for details.

To avoid spurious logging from the underlying `WKWebView` in the Xcode console, you can set `OS_ACTIVITY_MODE` to `disable` in the Run properties for your target.

### SwiftUI Usage

In the simplest case, just use the `MarkupEditorView` like you would any other SwiftUI view. By default, on all but phone devices, it will place a `MarkupToolbar` above a `UIViewRepresentable` that contains the `MarkupWKWebView`, which is where you do your editing. On phone devices, it will make the toolbar the `inputAccessoryView` for the `MarkupWKWebView`, giving you access to the toolbar when the keyboard shows up. Your ContentView can act as the `MarkupDelegate`, which is almost certainly what you want to do in all but the simplest applications. The `MarkupEditorView` acts as the `MarkupDelegate` if you don't specify one yourself.

```
import SwiftUI
import MarkupEditor

struct SimplestContentView: View {
    
    @State private var demoHtml: String = "<h1>Hello World</h1>"
    
    var body: some View {
        MarkupEditorView(html: $demoHtml)
    }
    
}
```

### UIKit Usage

In the simplest case, just use the `MarkupEditorUIView` like you would any other UIKit view. By default, on all but phone devices, it will place a `MarkupToolbarUIView` above a `MarkupWKWebView`, which is where you do your editing. On phone devices, it will make the toolbar the `inputAccessoryView` for the `MarkupWKWebView`, giving you access to the toolbar when the keyboard shows up. Your ViewController can act as the `MarkupDelegate`, which is almost certainly what you want to do in all but the simplest applications.  The `MarkupEditorUIView` acts as the `MarkupDelegate` if you don't specify one yourself.

```
import UIKit
import MarkupEditor

class SimplestViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let markupEditorUIView = MarkupEditorUIView(html: "<h1>Hello World</h1>")
        markupEditorUIView.frame = view.frame
        markupEditorUIView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(markupEditorUIView)
    }
    
}
```

### Customizing The Toolbar

You can use either a compact style of toolbar with only buttons, or a labeled form that shows what each button does. The default style is labeled. If you want to use the compact form, set `MarkupEditor.style` to `.compact`.

You can customize the various toolbars by eliminating them and/or subsetting their contents. You do this by creating a new instance of `ToolbarContents` and assigning it to `ToolbarContents.custom`. The `MarkupMenu` also uses the `ToolbarContents` to customize what it holds, so it's important to have set `ToolbarContents.custom` *before* creating the `MarkupMenu`. An easy way to do that is to set it up in your `AppDelegate` by overriding `init()`. Here is an example that adds the `CorrectionToolbar` (that holds the `Undo` and `Redo` buttons and is off by default) and only includes Bold, Italic, and Underline as formats in the FormatToolbar. It also sets up to use the compact style and to allow local images (as discussed below):

```
override init() {
    MarkupEditor.style = .compact
    MarkupEditor.allowLocalImages = true
    let myToolbarContents = ToolbarContents(
        correction: true,  // Off by default but accessible via menu, hotkeys, inputAccessoryView
        // Remove code, strikethrough, subscript, and superscript as formatting options
        formatContents: FormatContents(code: false, strike: false, subSuper: false)
    )
    ToolbarContents.custom = myToolbarContents
}
```

## Local Images

Being able to insert an image into a document you are editing is fundamental. In Markdown, you do this by referencing a URL, and the URL can point to a file on your local file system. The MarkupEditor can do the same, of course, but when you insert an image into a document in even the simplest WYSIWYG editor, you don't normally have to think, "Hmm, I'll have to remember to copy this file around with my document when I move my document" or "Hmm, where can I stash this image so it will be accessible across the Internet in the future."  From an end-user perspective, the image is just part of the document. Furthermore, you expect to be able to paste images into your document that you copied from elsewhere. Nobody wants to think about creating and tracking a local file in that case.

The MarkUpEditor refers to these images as "local images", in contrast to images that reside external to the document. Both can be useful! When you insert a local image (by selecting it from the Image Toolbar or by pasting it into the document), the MarkupEditor creates a _new_ image file using a UUID for the file name. By default, that file resides in the same location as the text you are editing. For the demos, the document HTML and local image files are held in an `id` subdirectory of the URL found from `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)`. You can pass the `id` to your `MarkupWKWebView` when you create it - for example, it might be the name of the document you're editing. When the MarkupEditor creates a new local image file, your `MarkupDelegate` receives a notification via the `markupImageAdded(url: URL)` method, giving you the URL of the new local image.

Although local image support was a must-have in my case, it seems likely some MarkupEditor consumers would feel like it's overkill or would like to preclude its use. It also requires you to do something special with the local images when you save your document. For these reasons, there is an option to control whether to allow selection of images from local files. Local images are disallowed by default. To enable them, specify `MarkupEditor.allowLocalImages = true` early in your application lifecycle. This will add a Select button to the Image Toolbar.

A reminder: The MarkupEditor does not know how/where you want to save the document you're editing or the images you have added locally. This is the responsibility of your app.

## Tests

There are three test targets: `BasicTests`, `UndoTests`, and `RedoTests`. Proper undo and redo has been one of the more challenging parts of the project. Essentially, every time the MarkupEditor implements changes to the underlying DOM, it also has to support undoing and redoing those changes. (As a historical aside, the MarkupEditor does not use the deprecated HTML `document.execCommand`, except in a very limited way. The `execCommand` takes care of undo and redo for anything you use it for. For example, if you use `document.execCommand('bold')` to bold the document selection, undo and redo "just work", albeit leaving behind various spans and styles in their wake. Because the MarkupEditor doesn't use `execCommand`, the undo and redo logic for every operation supported by the MarkupEditor has been hand-crafted with a mixture of love, frustration, and occasional anger.)

The `BasicTests` target tests the "do" operations; i.e., the operations you can perform via the MarkupWKWebView API or one of the toolbars. The `UndoTests` do all the "do" operations of the BasicTests, _plus_ the "undo" of each one to make sure the original HTML is restored. The `RedoTests` do all the "do" and "undo" operations, _plus_ the "redo" of each one to make sure the results of the original "undo" are restored. As a result, running just the `RedoTests` will also do the equivalent of the `UndoTests`, and running `UndoTests` will also do the the equivalent of running `BasicTests`. The `RedoTests` take a while to run and can be considered to be a comprehensive run through the MarkupEditor functionality.

## Demos

If you consume just the package, you don't get the demo targets to build. If you create a workspace that contains the MarkupEditor project or just clone this repository, you will also get the two demo targets, creatively named `SwiftUIDemo` and `UIKitDemo`. There is also a MarkupEditor framework target in the project that is 100% the equivalent of the Swift package. By default, the demos both consume the framework, because I have found it to be a lot less hassle when developing the project in the early stage. The only difference between consuming the framework and the Swift package is how the `MarkupWKWebView` locates and loads its `markup.html` resource when it is instantiated.

The demos open `demo.html`, which contains information about how to use the MarkupEditor as an end user and shows you the capabilities. They populate the `leftToolbar` of the MarkupToolbar to include a `FileToolbar` that lets you create a new document for editing or open an existing HTML file. The `DemoContentView` (or `DemoViewController` in the UIKitDemo) acts both as the `MarkupDelegate` and the `FileToolbarDelegate`. As the `FileToolbarDelegate`, it opens a `TextView` to display the underlying raw HTML, which is nice for demo. The raw HTML updates as you type and make changes to the document, which is fun and has been helpful for debugging; however, you probably don't want to be doing heavyweight things like that for every keystroke in a real app.

The demo directories also contain a "Simplest" version of a SwiftUI View and UIKit UIViewController, since the `DemoContentView` and `DemoViewController` for the demos are more complex, with pickers and the raw HTML display brought in with the `FileToolbar`, and the support for selecting local images. If you want to try the "Simplest" versions out, just edit the `SceneDelegate` to point at the `SimplestContentView` or `SimplestViewController`.

## Status

The current version is feature-complete. I am now consuming it myself in another project I am developing, so changes are being driven primarily by MarkupEditor uptake in that project (and any issues people might raise).

### Known Issues

[Issues](https://github.com/stevengharris/MarkupEditor/issues) are being tracked on GitHub.

### History

#### *NOT RELEASED YET, work in `main`*

I consider `main` to be (nearly) feature complete. If you were consuming earlier versions, you may encounter breaking changes, but I wanted to get those done before Beta. For example, the MarkupWebView previously was a UIViewRepresentable of the MarkupWKWebView. It has been eliminated in favor of a SwiftUI MarkupEditorView and a separate MarkupWKWebViewRepresentable.

The major drivers of the pre-Beta work have been usability and proper support for touch devices. This release also completely eliminates any need for a user to know about the SubToolbar, which previous versions surfaced because of the need to overlay it on the MarkupWKWebView. This release includes a new MarkupEditorView and MarkupEditorUIView for SwiftUI and UIKit respectively. These Views/UIViews lay out and manage the MarkupToolbar and (new) MarkupToolbarUIView, providing a simpler end-user experience when you just want to drop in a View/UIView. There are lots of other improvements and features as outlined below.

##### Closed Issues

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

##### Usability

* MarkupEditor struct provides central access to configuration/customization
* MarkupEditorView sets up and manages the MarkupToolbar automatically for SwiftUI development
* MarkupEditorUIView set up and managed MarkupToolbarUIView automatically for UIKit development
* MarkupWKWebView automatically installs a customized MarkupToolbarUIView as the inputAccessoryView
* Eliminate need for users to set up EnvironmentObjects to use the MarkupEditor as in previous versions

#### Version 0.3.3

* Run build and tests on main using GitHub actions.
* Start using the GitHub issue tracker and PRs to monitor issues prior to Beta.
* Support multi-list operations.
* Support multi-indent/outdent operations.

#### Version 0.3.2

This is an intermediate release in support of multi-element operations. A multi-element operation involves selecting multiple elements (e.g., paragraphs or formatted text elements - basically a large selected area in the document) and applying an operation like changing styles, formatting (e.g., bold, italic), or list attributes.

* Support multi-style operations.
* Support multi-format operations.

#### Version 0.3.1

This version is getting closer feature-complete on Mac Catalyst. There have been some API changes from the 0.2 version, primarily driven by the new support for local images.

* Support local images in the edited document, the ability to insert an image from file as opposed to an external URL.
* Refactor tests into BasicTests, UndoTests, and RedoTests. Tests have no dependency on a host app.
* All operations support undo/redo properly (with the exception of selections across paragraphs, as cited in Known Issues).
* Support pasting HTML and images. (Previously only plain text was supported.)
* Menus work in the demos but are still incomplete.
* List editing responds properly to the Enter key at beginning, inside, and end of list items. Enter in an empty list item outdents until exiting the list.
* Tab is now strictly a table navigation mechanism and is no longer associated with indent/outdent operations.

#### Version 0.2.2

The labeled toolbar took up too much screen real estate in my other project, so I created a .compact form and made that selectable via ToolbarPreference. Now I have a way to add other preferences easily. I also needed a better way to communicate the selectionState and selectedWebView when I have an arbitrary number of MarkupWebViews being editing using a single MarkupToolbar. I set up MarkupEnv to accomplish that and adjusted the SwiftUIDemo and UIKitDemo to use it.

* Add this History section to the README.
* Make the toolbar configurable between .compact (the new default) and .labeled via ToolbarPreference.
* Use MarkupEnv to access the selectionState and selectedWebView.
* Bundle loading logic now depends on SWIFT_PACKAGE in MarkupWKWebView, not my homegrown USEFRAMEWORK setting.
* Some minor adjustments to backgrounds and css to fix issues when the MarkupToolbar and MarkupWebView were embedded in other SwiftUI views.

#### Version 0.2.1

* This was the first version made public and open sourced.

## Legacy and Acknowledgements

When I started my search for an open source "Swift WYSIWYG editor", I found a kind of mishmash of things. The [RichEditorView](https://github.com/cjwirth/RichEditorView) was one of the most visible. The RichEditorView was originally built using UIWebView, which has long been deprecated. A couple of people [forked](https://github.com/cbess/RichEditorView/) and [ported](https://github.com/YoomamaFTW/RichEditorView) it to WKWebView and shared their work. I used that for a while in some work I was doing, but I kept hitting edges and felt like I was having to put a lot of work into a fork that would never really see the light of day. The thought of moving the result into SwiftUI was making me queasy. The MarkupEditor is meant to be a proper "modern" version for WYSIWYG editing you can use in your SwiftUI or UIKit project, but it was hatched in the original RichEditorView.

The MarkupEditor's approach of using an HTML document containing a `contentEditable` DIV under the covers seems like a good idea until you read Nick Santos' article about [Why ContentEditable is Terrible](https://medium.engineering/why-contenteditable-is-terrible-122d8a40e480). His main arguments center around WYSIWYG, and the meaning of the term when editing a document in this way. In the simplest case, consider if you save the HTML you edited using the MarkupEditor and then use a different CSS to display it in a different browser. What you saw when you edited will certainly not be what you get. The text content will be 100% the same, of course. If what you are editing and saving remains in the same HTML form and is presented using the same CSS using a WKWebView, then it will be WYSIWYG. In any case, you need to think about it when adopting this approach. 

The MarkupEditor has the advantage of not supporting arbitrary HTML, and in fact, owns the definition of the exact subset of HTML that is allowed. It is targeted only at WKWebView, so there are no browser portability problems. The restrictions on functionality and the absence of styling elements from the HTML help avoid some of the problems cited in [his article](https://medium.engineering/why-contenteditable-is-terrible-122d8a40e480). Also, by avoiding use of (the now deprecated but likely to live forever) [Document.execCommand](https://developer.mozilla.org/en-US/docs/Web/API/Document/execCommand) to perform editing tasks against the DOM, the MarkupEditor avoids WebKit polluting the "clean" HTML with spans and styles.

In case you think "To heck with this contentEditable nonsense. How hard can it be to build a little editor!?", I refer you to this [article on lord.io](https://lord.io/text-editing-hates-you-too/). I did not enjoy writing JavaScript while implementing this project, but the DOM and its incredibly well-documented API are proven and kind of amazing. To be able to ride on top of the work done in the browser is a gift horse that should not be looked in the mouth.
