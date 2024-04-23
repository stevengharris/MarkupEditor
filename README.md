<p align="center">
    <img src="https://github.com/stevengharris/MarkupEditor/actions/workflows/swift.yml/badge.svg">
    <img src="https://img.shields.io/badge/Swift-5.7+-blue.svg">
    <img src="https://img.shields.io/badge/iOS-15+-blue.svg" alt="iOS 14.5+">
    <img src="https://img.shields.io/badge/MacCatalyst-15+-blue" alt="MacCatalyst 14.5+">
    <a href="https://twitter.com/stevengharris">
        <img src="https://img.shields.io/badge/Contact-@stevengharris-lightgrey.svg?style=flat" alt="Twitter: @stevengharris">
    </a>
</p>

# MarkupEditor

### 

WYSIWYG editing for SwiftUI and UIKit apps.

Jealous of those JavaScript coders with their WYSIWYG text editors, but just can't stomach the idea of immersing yourself in JavaScript when you're enjoying the comfort and joy of Swift? Yeah, me too. So when I was forced to do it, I thought I'd share what I did as a way to help others avoid it.

## Demo

![MarkupEditor](https://user-images.githubusercontent.com/1020361/188996859-0c32da80-151d-4595-8321-9bccd059b1a1.mp4)

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

To avoid spurious logging from the underlying `WKWebView` in the Xcode console, you can set `OS_ACTIVITY_MODE` to `disable` in the Run properties for your target. However, this has the side-effect of removing OSLog messages from the MarkupEditor from showing up, too, and is probably not a good idea in general.

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

### Getting Edited HTML

As you edit your document, you can see its contents change in proper WYSIWYG fashion. The document HTML is *not* automatically passed back to Swift as you make changes. You must retrieve the HTML at an appropriate place in your app using `MarkupWKWebView.getHtml()`. This leaves the question: what is "an appropriate place"? The answer is dependent on how you are using the MarkupEditor. In the demo, where you can display the HTML as you type, the HTML is retrieved at every keystroke by using the `MarkupDelegate.markupInput(_:)` method. This is generally going to be a bad idea, since it makes typing much more heavyweight than it should be. You might only retrieve the edited HTML when your user presses a "Save" button. You might want to implement an autosave type of approach by tracking when changes are happening using `MarkupDelegate.markupInput(_:)`, and only invoking `MarkupWKWebView.getHtml()` when enough time has passed.

The `getHtml()` method needs to be invoked on a MarkupWKWebView instance. Generally you will need to hold onto that instance yourself in your MarkupDelegate. You can get access to it in almost all of the MarkupDelegate methods (e.g., `MarkupWKWebView.markupLoaded` or `MarkupWKWebView.markupInput`). Using `MarkupEditor.selectedWebView` to get the instance will not be reliable, because the value becomes nil when no MarkupWKWebView has focus.

Note that in SwiftUI, when you pass HTML to the MarkupEditorView, you pass a binding to a String. For example:

```
@State private var demoHtml: String = "<h1>Hello World</h1>"
    
var body: some View {
    MarkupEditorView(html: $demoHtml)
}
```

In this example, `demoHtml` is **not** modified by the MarkupEditor as you edit the document. The `html` is passed as a binding so that you can modify it from your app. You must use `MarkupWKWebView.getHtml()` to get the modified HTML.

## Customizing the MarkupEditor

You can do some limited customization of the MarkupToolbar and the MarkupEditor behavior overall. You should always do these customizations early in your app lifecycle.

You can also provide your own CSS-based style customization and JavaScript scripts for the MarkupEditor to use in your app. The StyledContentView and StyledViewController demonstrate usage of custom CSS and scripts on the `demo.html` document and are discussed below.

### Customizing the Toolbar

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

Note that the MarkupToolbar uses the static value `MarkupEditor.selectedWebView` to determine which MarkupWKWebView to invoke operations on. This means that generally you should only have a single MarkupToolbar. It's possible to use multiple MarkupToolbars in your app, but you need to be aware that they will each operate against and display the state of the MarkupWKWebView held in `MarkupEditor.selectedWebView`.

### Customizing Document Style

A great byproduct of using HTML under the covers of the MarkupEditor is that you can use CSS to style the way the document looks. To do so means you need to know something about CSS and a bit about the internals of the MarkupEditor. 

The MarkupEditor uses a subset of HTML elements and generally does not specify the HTML element "class" at all. (The one exception is for images and the associated resizing handles that are displayed when you select an image.) The MarkupEditor uses the following HTML elements:

* Paragraph Styles: `<H1>`, `<H2>`, `<H3>`, `<H4>`, `<H5>`, `<H6>`, `<P>`. `<P>` is the default style, also referred to as "Normal" in various places.
* Formatting: `<B>`, `<I>`, `<U>`, `<CODE>`, `<DEL>`.
* Images: `<IMG class="resize-image">`. The internal details of the styling and classes to support resizable images are in `markup.js` but will not be covered here.
* Links: `<A>`.
* Lists: `<UL>`, `<OL>`, `<LI>`.
* Tables: `<TABLE>`, `<THEAD>`, `<TBODY>`, `<TR>`, `<TH>`, `<TD>`.
* Indenting: `<BLOCKQUOTE>`.

All editable content is contained in a single `<DIV>` with the id of `editor`. Occasionally a `<BR>` element will be used to enable selection within an empty element. For example, if you hit Enter, the MarkupEditor produces a new paragraph as `<P><BR></P>`. `<SPAN>` elements are used for the image resizing handles but are never returned in HTML when you use `MarkupWKWebView.getHtml()`

The MarkupEditor uses a "baseline" styling that is provided in `markup.css`. One way to customize the MarkupEditor style is to fork the repository and edit `markup.css` to fit your needs. A less intrusive mechanism is to include your own CSS file with your app that uses the MarkupEditor, and identify the file using `MarkupWKWebViewConfiguration` that you can pass when you instantiate a MarkupEditorView or MarkupEditorUIView. The CSS file you identify this way is loaded *after* `markup.css`, so its contents follows the normal [CSS cascading rules](https://russmaxdesign.github.io/maxdesign-slides/02-css/207-css-cascade.html#/). 

To specify the MarkupWKWebViewConfiguration, you might hold onto it in your MarkupDelegate as `markupConfiguration = MarkupWKWebViewConfiguration()`. Assuming you created a custom CSS file called `custom.css` and packaged it as a resource with your app, specify it in the `markupConfiguration` using:

```
markupConfiguration.userCssFile = "custom.css"
```

Here is an example of how to override the `font-weight: bold` used for `<H4>` in `markup.css`:

```
h4 {
    font-weight: normal;
}
```

Here is an example showing how to modify the caret and selection colors (blue by default), with special behavior for dark mode:

```
#editor {
    caret-color: black;
}
@media (prefers-color-scheme: dark) {
    #editor {
        caret-color: yellow;
    }
}
```

CSS is an incredibly powerful tool for customization. The contents of `markup.css` itself are minimal but show you how the basic elements are styled by default. If there is something the MarkupEditor is doing to prevent the kind of custom styling you are after, please file an issue; however, please do not file issues with questions about CSS.

### Adding Custom Scripts

MarkupEditor functionality that modifies and reports on the state of the HTML DOM in the MarkupWKWebView is all contained in `markup.js`. If you have scripting you want to add, there are two mechanisms for doing so:

1. Create an array of strings that contain valid JavaScript scripts that will be loaded after `markup.js`. Pass these scripts to the MarkupEditorView or MarkupEditorUIView using the `userScripts` parameter at instantiation time.
2. Create a file containing your JavaScript code, and identify the file in your MarkupWKWebViewConfiguration.

To specify the MarkupWKWebViewConfiguration, you might hold onto it in your MarkupDelegate as `markupConfiguration = MarkupWKWebViewConfiguration()`. Assuming you created a script file called `custom.js` and packaged it as a resource with your app, specify it in the `markupConfiguration` using:

```
markupConfiguration.userScriptFile = "custom.js"
```

The `userScriptFile` is loaded after `markup.js`. Your code can use the functions in `markup.js` or which you loaded using `userScripts` if needed.

To invoke a function in your custom script, you should extend the MarkupWKWebView. For example, if you have a `custom.js` file that contains this function:

```
/**
 * A public method that can be invoked from MarkupWKWebView to execute the
 * assignment of classes to h1 and h2 elements, so that custom.css styling
 * will show up. Invoking this method requires an extension to MarkupWKWebView
 * which can be called from the MarkupDelegate.markupLoaded method.
 */
MU.assignClasses = function() {
    const h1Elements = document.getElementsByTagName('h1');
    for (let i = 0; i < h1Elements.length; i++) {
        element = h1Elements[i];
        element.classList.add('title');
    };
    const h2Elements = document.getElementsByTagName('h2');
    for (let i = 0; i < h2Elements.length; i++) {
        element = h2Elements[i];
        element.classList.add('subtitle');
    };
};
```

then you can extend MarkupWKWebView to be able to invoke `MU.assignClasses`:

```
extension MarkupWKWebView {
    
    /// Invoke the MU.assignClasses method on the JavaScript side that was added-in via custom.js.
    public func assignClasses(_ handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.assignClasses()") { result, error in
            if let error {
                print(error.localizedDescription)
            }
            handler?()
        }
    }
    
}
```

The StyledContentView and StyledViewController demos use this approach along with `custom.css` to set the `title` class on `H1` elements, and `subtitle` class on `H2` elements and apply styling to them. This is a contrived use case (you could just use `custom.css` to style `H1` and `H2` directly), but it shows both custom scripting and CSS being used.

## Local Images

Being able to insert an image into a document you are editing is fundamental. In Markdown, you do this by referencing a URL, and the URL can point to a file on your local file system. The MarkupEditor can do the same, of course, but when you insert an image into a document in even the simplest WYSIWYG editor, you don't normally have to think, "Hmm, I'll have to remember to copy this file around with my document when I move my document" or "Hmm, where can I stash this image so it will be accessible across the Internet in the future."  From an end-user perspective, the image is just part of the document. Furthermore, you expect to be able to paste images into your document that you copied from elsewhere. Nobody wants to think about creating and tracking a local file in that case.

The MarkUpEditor refers to these images as "local images", in contrast to images that reside external to the document. Both can be useful! When you insert a local image (by selecting it from the Image Toolbar or by pasting it into the document), the MarkupEditor creates a _new_ image file using a UUID for the file name. By default, that file resides in the same location as the text you are editing. For the demos, the document HTML and local image files are held in an `id` subdirectory of the URL found from `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)`. You can pass the `id` to your `MarkupWKWebView` when you create it - for example, it might be the name of the document you're editing. When the MarkupEditor creates a new local image file, your `MarkupDelegate` receives a notification via the `markupImageAdded(url: URL)` method, giving you the URL of the new local image.

Although local image support was a must-have in my case, it seems likely some MarkupEditor consumers would feel like it's overkill or would like to preclude its use. It also requires you to do something special with the local images when you save your document. For these reasons, there is an option to control whether to allow selection of images from local files. Local images are disallowed by default. To enable them, specify `MarkupEditor.allowLocalImages = true` early in your application lifecycle. This will add a Select button to the Image Toolbar.

A reminder: The MarkupEditor does not know how/where you want to save the document you're editing or the images you have added locally. This is the responsibility of your app.

## Search

This section addresses searching within the document you are editing using the MarkupEditor but also provides some guidance on searching for the documents you create or edit using MarkupEditor.

### Searching Within A Document

For many applications, you will have no need to search the content you are editing in the MarkupEditor. But when content gets larger, it's very handy to be able to find a word or phrase, just like you would expect in any text editor. The MarkupEditor supports search with the function:

```
func search(
    for text: String,
    direction: FindDirection,
    activate: Bool = false,
    handler: (() -> Void)? = nil
)
```

The FindDirection is either `.forward` or `.backward`, indicating the direction to search from the selection point in the document. The MarkupWKWebView scrolls to make the text that was found visible. 

Specify `activate: true` to activate a "search mode" where Enter is interpreted as meaning "search for the next occurrence in the forward direction". (Shift+Enter searches backward.) Often when you are searching in a large document, you want to just type the search string, hit Enter, see what was selected, and hit Enter again to continue searching. This "search mode" style is supported in the MarkupEditor by capturing Enter on the JavaScript side and interpreting it as `searchForward` (or Shift+Enter for `searchBackward`) until you do one of the following:

1. You invoke `MarkupWKWebView.deactivateSearch(handler:)` to stop intercepting Enter/Shift+Enter, but leaving the search state in place.
2. You invoke `MarkupWKWebView.cancelSearch(handler:)` to stop intercepting Enter/Shift+Enter and clear all search state.
3. You click-on, touch, or otherwise type into the document. Your action automatically disables intercepting of Enter/Shift+Enter.

Note that by default, search mode is never activated. To activate it, you must use `activate: true` in your call to `MarkupWKWebView.search(for:direction:activate:handler:)`.

The SwiftUI demo includes a `SearchableContentView` that uses a `SearchBar` to invoke search on `demo.html`. The `SearchBar` is not part of the MarkupEditor library, since it's likely most users will implement search in a way that is specific to their app. For example, you might use the `.searchable` modifier on a NavigationStack. You can use the `SearchBar` as a kind of reference implementation, since it also demonstrates the use of "search mode" by specifying `activate: true` when you submit text in the `SearchBar's` TextField.

### Searching for MarkupEditor Documents

You can use CoreSpotlight to search for documents created by the MarkupEditor. That's because CoreSpotlight already knows how to deal properly with HTML documents. To be specific, this means that when you put a table and image in your document, although the underlying HTML contains `<table>` and `<image>` tags, the indexing works on the DOM and therefore only indexes the text content. If you search for "table" or "image", it won't find your document unless there is a text element containing the word "table" or "image".

How might you make use of CoreSpotlight? Typically you would have some kind of model object whose `contents` includes the HTML text produced-by and edited-using the MarkupEditor. Your model objects can provide indexing functionality. Here is an example (with some debug printing and \<substitutions> below):

```
/// Add this instance of MyModelObject to the Spotlight index
func index() {
    let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.html)
    attributeSet.kind = "<MyModelObject>"
    let contentData = contents.data(using: .utf8)
    // Set the htmlContentData based on the entire document contents
    attributeSet.htmlContentData = contentData
    if let data = contentData {
        if let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            // Put a snippet of content in the contentDescription that will show up in Spotlight searches
            if attributedString.length > 30 {
                attributeSet.contentDescription = "\(attributedString.string.prefix(30))..."
            } else {
                attributeSet.contentDescription = attributedString.string
            }
        }
    }
    // Now create the CSSearchableItem with the attributeSet we just created, using MyModelObject's unique id
    let item = CSSearchableItem(uniqueIdentifier: <MyModelObject's id>, domainIdentifier: <MyModelObject's container domain>, attributeSet: attributeSet)
    item.expirationDate = Date.distantFuture
    CSSearchableIndex.default().indexSearchableItems([item]) { error in
        if let error = error {
            print("Indexing error: \(error.localizedDescription)")
        } else {
            print("Search item successfully indexed!")
        }
    }
}

/// Remove this instance of MyModelObject from the Spotlight index
func deindex() {
    CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [idString]) { error in
        if let error = error {
            print("Deindexing error: \(error.localizedDescription)")
        } else {
            print("Search item successfully removed!")
        }
    }
}
```

Once you have indexed your model objects, you can then execute a case-insensitive search query to locate model objects that include a `text` String like this:

```
let queryString = "domainIdentifier == \'\(<MyModelObject's id)\' && textContent == \"*\(text)*\"c"
searchQuery = CSSearchQuery(queryString: queryString, attributes: nil)
searchQuery?.foundItemsHandler = { items in
    ...
    ... Append contents of items to an array tracking the MyModelObjects that contain text
    ...
}
searchQuery?.completionHandler = { error in
    ...
    ... Do whatever you need afterward, such as additional filtering
    ...
}
// Then run the query
searchQuery?.start()
```

Then, if you need to locate the `text` in the document itself once you dereference it from the `id`, you would use the approach in [Searching Within A Document](#searching-within-a-document) on a MarkupWKWebView containing the `contents`.

## Tests

There are three test targets: `BasicTests`, `UndoTests`, and `RedoTests`. Proper undo and redo has been one of the more challenging parts of the project. Essentially, every time the MarkupEditor implements changes to the underlying DOM, it also has to support undoing and redoing those changes. (As a historical aside, the MarkupEditor does not use the deprecated HTML `document.execCommand`, except in a very limited way. The `execCommand` takes care of undo and redo for anything you use it for. For example, if you use `document.execCommand('bold')` to bold the document selection, undo and redo "just work", albeit leaving behind various spans and styles in their wake. Because the MarkupEditor doesn't use `execCommand`, the undo and redo logic for every operation supported by the MarkupEditor has been hand-crafted with a mixture of love, frustration, and occasional anger.)

The `BasicTests` target tests the "do" operations; i.e., the operations you can perform via the MarkupWKWebView API or one of the toolbars. The `UndoTests` do all the "do" operations of the BasicTests, _plus_ the "undo" of each one to make sure the original HTML is restored. The `RedoTests` do all the "do" and "undo" operations, _plus_ the "redo" of each one to make sure the results of the original "undo" are restored. As a result, running just the `RedoTests` will also do the equivalent of the `UndoTests`, and running `UndoTests` will also do the the equivalent of running `BasicTests`. The `RedoTests` take a while to run and can be considered to be a comprehensive run through the MarkupEditor functionality.

## Demos

If you consume just the package, you don't get the demo targets to build. If you create a workspace that contains the MarkupEditor project or just clone this repository, you will also get the two demo targets, creatively named `SwiftUIDemo` and `UIKitDemo`. There is also a MarkupEditor framework target in the project that is 100% the equivalent of the Swift package. By default, the demos both consume the framework, because I have found it to be a lot less hassle when developing the project in the early stage. The only difference between consuming the framework and the Swift package is how the `MarkupWKWebView` locates and loads its `markup.html` resource when it is instantiated.

The demos open `demo.html`, which contains information about how to use the MarkupEditor as an end user and shows you the capabilities. They populate the `leftToolbar` of the MarkupToolbar to include a `FileToolbar` that lets you create a new document for editing or open an existing HTML file. The `DemoContentView` (or `DemoViewController` in the UIKitDemo) acts both as the `MarkupDelegate` and the `FileToolbarDelegate`. As the `FileToolbarDelegate`, it opens a `TextView` to display the underlying raw HTML, which is nice for demo. The raw HTML updates as you type and make changes to the document, which is fun and has been helpful for debugging; however, you probably don't want to be doing heavyweight things like that for every keystroke in a real app.

The demo directories also contain a "Simplest" version of a SwiftUI View and UIKit UIViewController, since the `DemoContentView` and `DemoViewController` for the demos are more complex, with pickers and the raw HTML display brought in with the `FileToolbar`, and the support for selecting local images. If you want to try the "Simplest" versions out, just edit the `SceneDelegate` to point at the `SimplestContentView` or `SimplestViewController`.

As discussed in the [Searching Within A Document](#searching-within-a-document) section, a SwiftUI `SearchableContentView` is also provided to demonstrate the ability to search within a MarkupEditor HTML document, along with a `SearchBar` to invoke the functionality.

## Status

The current version is a feature-complete Beta. I am now consuming it myself in another project I am developing, so changes are being driven primarily by MarkupEditor uptake in that project (and any issues people might raise).

### Known Issues

[Issues](https://github.com/stevengharris/MarkupEditor/issues) are being tracked on GitHub.

### History

#### Version 0.7.1 (Beta 5)

* Support multiple editable areas in a single document (https://github.com/stevengharris/MarkupEditor/pull/195). There is a very small SwiftUI-only demo (see DivsContentView in the SwiftUIDemo) of the capability, but the feature is as-yet undocumented. See the [discussion](https://github.com/stevengharris/MarkupEditor/discussions/178) for some more detail.
* Search improvements, including:
  * When in search mode, interpret Enter as "search forward" and Shift+Enter as "search backward".
  * Outline the selection while in search mode with a border, so it's clearer where you are in the document.
  * Slightly darken background while in search mode, to indicate visually that Enter and Shift+Enter are being interpreted as search forward and backward.
  * Highlight all strings matching the search string, so you can see where Enter and Shift+Enter will move next. Note that highlighting, which depends on the CSS custom highlight API (ref: https://developer.mozilla.org/en-US/docs/Web/API/CSS_Custom_Highlight_API) only works in Safari 17.2 or later, which won't be available in older runtimes still supported by the MarkupEditor.
  * Add MarkupDelegate callbacks `markupActivateSearch` and `markupDeactivateSearch`, default behavior for which is to toggle `MarkupEditor.searchActive` state so the MarkupToolbar can be disabled/enabled while in search mode.
  * Limit search to contenteditable divs (generally there is only one, `MU.editor`).

#### Version 0.7.0 (Beta 4)

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

#### Version 0.6.2 (Beta 3)

* Update README to clarify how to get modified HTML, a recurring issue for users (e.g., https://github.com/stevengharris/MarkupEditor/issues/176).
* Update README to include a [Customizing the MarkupEditor](#customizing-the-markupeditor) section.
* Add ability to customize [CSS](#customizing-document-style) and [scripts](#adding-custom-scripts) in MarkupWKWebViewConfiguration.
* Fixed various paste issues (https://github.com/stevengharris/MarkupEditor/issues/184, https://github.com/stevengharris/MarkupEditor/issues/179, https://github.com/stevengharris/MarkupEditor/issues/128).
* Removed empty text element left on formatting (https://github.com/stevengharris/MarkupEditor/issues/181).

#### Version 0.6.0 (Beta 2)

There have been a lot of changes since Beta 1 was released. Beta 2 pulls them all together in what I hope is closer to a proper release candidate.

#### Features

* The MarkupEditor did not support text search, but now does. See [Search](#search) in this README.
* There was no way to provide "placeholder" text for an empty MarkupWKWebView, but it is now supported.  (https://github.com/stevengharris/MarkupEditor/issues/101)
* Setting the selection when the MarkupWKWebView is opened (which updates the MarkupToolbar) was automatic but is now optional. (https://github.com/stevengharris/MarkupEditor/issues/70)

#### Closed Issues

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

#### Version 0.5.1 (Beta 1)

Fix a tagging issue for the Swift package.

#### Version 0.5.0 (Beta 1)

This is the first Beta release for the MarkupEditor! Please see [the announcement and discussion](https://github.com/stevengharris/MarkupEditor/discussions/52) about it.

##### Closed Issues

* Replace LinkToolbar and ImageToolbar with popovers ([Issue 42](https://github.com/stevengharris/MarkupEditor/issues/42))
* Build from package is broken on iOS ([Issue 47](https://github.com/stevengharris/MarkupEditor/issues/47))
* Touch device selection doesn't work properly ([Issue 48](https://github.com/stevengharris/MarkupEditor/issues/48))
* Make paragraph style an optional part of StyleToolbar ([Issue 49](https://github.com/stevengharris/MarkupEditor/issues/49))

#### Version 0.4.0

I consider this release to be feature complete with the exception of some remaining UX problems on touch devices. If you were consuming earlier versions, you may encounter breaking changes, but I wanted to get those done before Beta. For example, the MarkupWebView previously was a UIViewRepresentable of the MarkupWKWebView. It has been eliminated in favor of a SwiftUI MarkupEditorView and a separate MarkupWKWebViewRepresentable.

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
* Support pinch gesture for image resizing ([Issue 38](https://github.com/stevengharris/MarkupEditor/issues/38))
* InputAccessoryView disappears on device rotation ([Issue 39](https://github.com/stevengharris/MarkupEditor/issues/39))
* Provide context menus (copy/cut/paste) ([Issue 45](https://github.com/stevengharris/MarkupEditor/issues/45))

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
