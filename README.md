# MarkupEditor

WYSIWYG editing for SwiftUI and UIKit apps

Copyright © 2021 Steven G. Harris. All rights reserved.

Jealous of those JavaScript coders with their WYSIWYG text editors, but just can't stomach the idea of immersing yourself in JavaScript when you're enjoying the comfort and joy of Swift? Yeah, me too. So when I was forced to do it, I thought I'd share what I did as a way to help others avoid it.

## MarkupEditor Goals and Non-Goals

I am working on a larger project that requires embedded support for "rich text" editing. I felt like WYSIWYG editing was a must-have requirement. I could have forced my developer-users to use Markdown, but I find it to be annoying both to write and to look at while writing. Who wants to have to mentally filter all that cruft on the screen? It's a lot better than editing raw HTML, but come on, this is the 21st century. Having to deal with an editing experience where you use some kind of preview mode to make sure what you are writing will be presented like you expect feels like CI/CD for writing. 

Still, I wanted an editing experience that didn't get in the way. I wanted something with the feature-simplicity of Markdown, but presented in a clean, what-you-see-is-what-you-get manner that supported the basics people expect:

1. Styling
    * Present a paragraph or header with a predefined font size
    * Support bulleted and numbered lists
    * Support indenting
2. Formatting
    * Bold, italic, underline, code, strikethrough, sub- and super-scripting
3. Embedding
    * Images
    * Tables
    * Links
4. Undo/redo

As you might expect, then, this feature set is pretty darned close to Markdown - or at least a GitHub flavor of Markdown. It doesn't include a lot of things you might expect from your favorite word processor:

* Colored text
* Highlighting
* Font size changes (except as implied by identifying something as a paragraph or header)

The initial open source release does not support the following, but will:

* Text alignment (although how well this translates back-and-forth to Markdown remains to be seen)
* Better table formatting
* Copy/paste preserving formatting (currently only supports plain text)

If you want a richer feature set, you can extend the MarkupEditor to do these yourself. The demos include examples of how to extend the MarkupEditor's core features and how to interact with the file system for saving what you edit. It's my intent to keep the core MarkupEditor feature set to be similar to what you will see in GitHub Markdown.

### What is WYSIWYG, Really?

The MarkupEditor is presenting an HTML document to you as you edit. It uses JavaScript to change the underlying DOM and calls back into Swift as you interact with the document. The MarkupEditor does not know how to save your document or transform it to some other format. This is something your application that consumes the MarkupEditor will need to do. The MarkupEditor will let your `MarkupDelegate` know as the underlying document changes state, and you can take advantage of those notifications to save and potentially transform the HTML into another form. If you're going to do that, then you should make sure that round-tripping back into HTML also works flawlessly. Otherwise, you are using a "What You See Is Not What You Get" editor, which is both less pronounceable and much less useful to your end users.

## Consuming the MarkupEditor

Behind the scenes, the MarkupEditor interacts with a single `contentEditable` DIV element created in `markup.html` to modify the DOM of the document you are editing. It uses a subclass of `WKWebView` - the `MarkupWKWebView` - to make calls to the JavaScript in `markup.js`. In turn, the JavaScript calls back into Swift to let the Swift side know that changes occurred. The callbacks on the Swift side are handled by the `MarkupCoordinator`. The `MarkupCoordinator` is the `WKScriptMessageHandler` for a single  `MarkupWKWebView` and receives all the JavaScript callbacks in `userContentController(_:didReceive:)`.  The `MarkupCoordinator` in turn notifies your `MarkupDelegate` of changes. See `MarkupDelegate.swift` for the full protocol and default implementations. 

That sounds complicated, but it is mostly implementation details you should not need to worry about. The `MarkupDelegate` protocol is the key mechanism for your app to find out about changes as the user interacts with the document. The `MarkupWKWebView` is the key mechanism to make changes to the document from the Swift side or to obtain information from the document, such as its contents. The `MarkupToolbar` is a convenient, pre-built UI to invoke changes to the document by interacting with the `MarkupWKWebView`.

To avoid spurious logging from the underlying WKWebView in the Xcode console, you can set `OS_ACTIVITY_MODE` to `disable` in the Run properties for your target.

### Swift Package

Add the `MarkupEditor` package to your Xcode project using File -> Swift Packages -> Add Package Dependency...

### Framework

Clone this repository and build the MarkupFramework target in Xcode. Add the MarkupEditor.framework as a dependency to your project.

### SwiftUI Usage

When consuming the MarkupEditor in SwiftUI, you can use the `MarkupToolbar` and `MarkupWebView` directly in your own View. The `MarkupWebView` is a UIViewRepresentable for the `MarkupWKWebView` and deals with setting up the `MarkupCoordinator` itself.

For example, you can add the `MarkupToolbar` and a `MarkupWebView` to your `ContentView`. The `selectionState` and `selectedWebView` have to be accessed by both the `MarkupToolbar` and `MarkupWebView`, so can be held as state in `ContentView`. By setting your `ContentView` as the `markupDelegate`, it will receive the `markupTookFocus` callback when the underlying `MarkupWKWebView` has loaded its content along with the JavaScript held in `markup.js`. The example below shows how to use the `markupTookFocus` callback to assign the `selectedWebView` so that the `MarkupToolbar` correctly reflects the `selectionState` as the user edits and positions the caret in the document.

```
import SwiftUI
import MarkupEditor

struct ContentView: View {
    @StateObject var selectionState = SelectionState()
    @State var selectedWebView: MarkupWKWebView?
    
    var body: some View {
        VStack {
            MarkupToolbar(
                selectionState: selectionState,
                selectedWebView: $selectedWebView,
                markupDelegate: self
            )
            MarkupWebView(
                selectionState: selectionState,
                selectedWebView: $selectedWebView,
                markupDelegate: self,
                initialContent: "<h1>Hello world!</h1>"
            )
        }
    }
}

extension ContentView: MarkupDelegate {
    
    func markupTookFocus(_ view: MarkupWKWebView) {
        selectedWebView = view
    }

}
```

### UIKit Usage

The `MarkupToolbar` is a SwiftUI View, so consuming it in UIKit is a bit more complicated than in SwiftUI. You also need to create and hook up the `MarkupCoordinator` yourself, something that is done by the SwiftUI `MarkupWebView`. Please refer to the UIKitDemo code.

## Demos

If you consume just the package, you don't get the demos. If you create a workspace that contains the MarkupEditor project or just clone this repository, you will also get the two demo targets, creatively named `SwiftUIDemo` and `UIKitDemo`. There is also a MarkupEditor framework target in the project that is 100% the equivalent of the Swift package. By default, the demos both consume the framework, because I find it to be a lot less hassle when developing the project overall, especially in the early stage. The only difference between consuming the framework and the Swift package is how the `MarkupWKWebView` locates and loads its `markup.html` resource when it is instantiated.

The demos open `demo.html`, which contains information about how to use the MarkupEditor as an end user and shows you the capabilities.

## Status

The current version is very much a work in progress. The work is a back-and-forth between the MarkupEditor package proper and the two demos. I am releasing it now because I think I can consume it properly in my other project, which will provide useful feedback beyond the demos.

### Known Issues

1. At this point, the MarkupEditor is really only useful on devices with a keyboard. On the iPad (and worse on the iPhone), the toolbar is too wide, and it isn't set up for scrolling or, better, for a different display for the format. I intend to work on the iPad usage but have not put any time into it. I am primarily focused on using it on the Mac.
2. Caret occasionally goes missing. After some editing operations, the insertion point caret is properly placed but disappears. Moving the arrow keys or typing will reveal it.
3. Table editing
    * Table formatting is pretty bad. I plan to provide options for putting borders around elements, header, etc.
    * Table tabbing is not working properly.
    * Headers are currently colspanning the full table, but this needs to be adjustable.
4. Image selection is funky.
5. Image scaling is clunky. I plan to replace this with an overlay with handles on the image.

### Limitations

1. Needs to support text justification. Initially I thought I could live without it, since it's not properly supported in Markdown. But, especially with tables, it is really a must-have.
2. Preferences. I need to parameterize various things and make them settable by preferences.

## Legacy and Acknowledgements

When I started my search for a "Swift WYSIWYG editor", I found a kind of mishmash of things. The [RichEditorView](https://github.com/cjwirth/RichEditorView) was one of the most visible. The RichEditorView was originally built using UIWebView, which has long been deprecated. A couple of people [forked](https://github.com/cbess/RichEditorView/) and [ported](https://github.com/YoomamaFTW/RichEditorView) it to WKWebView and shared their work. I used that for a while in some work I was doing, but I kept hitting edges and felt like I was having to put a lot of work into a fork that would never really see the light of day. The thought of moving the result into SwiftUI was making me queasy. The MarkupEditor is meant to be a proper "modern" version for WYSIWYG editing you can use in your SwiftUI or UIKit project, but it was hatched in the original RichEditorView.

The Markdown editor uses an html document containing a contentEditable div under the covers, which seems like a good idea until you read Nick Santos' article about [Why ContentEditable is Terrible](https://medium.engineering/why-contenteditable-is-terrible-122d8a40e480). His main arguments center around WYSIWYG, and the meaning of the term when editing a document in this way. In the simplest case, consider if you save the HTML you edited using the MarkupEditor and then use a different css to display it in a different browser. What you saw when you edited will certainly not be what you get. The text content will be 100% the same, of course. If what you are editing and saving remains in the same html form and is presented using the same css using a WKWebView, then it will be WYSIWYG. In any case, you need to think about it when adopting this approach.

In case you think "To heck with this contentEditable nonsense. How hard can it be to build a little editor!?", I refer you to this [article on lord.io](https://lord.io/text-editing-hates-you-too/). I may have hated every moment writing JavaScript while implementing this project, but the DOM and its incredibly well-documented API are proven and kind of amazing. To be able to ride on top of the work done in the browser is a gift horse that should not be looked in the mouth.
