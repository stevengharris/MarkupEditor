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

Jealous of those JavaScript coders with their WYSIWYG text editors, but unwilling to take on integrating one into your comfy Swift world? Yeah, me too. So, when I did that to use in another project, I thought I'd share what I did as a way to help others avoid it.

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

The MarkupEditor is presenting an HTML document to you as you edit. It uses a JavaScript library, [ProseMirror](https://prosemirror.net), to change the underlying DOM and call back into Swift as you interact with the document. The MarkupEditor does not know how to save your document or transform it to some other format. This is something your application that consumes the MarkupEditor will need to do. The MarkupEditor will let your `MarkupDelegate` know as the underlying document changes state, and you can take advantage of those notifications to save and potentially transform the HTML into another form. If you're going to do that, then you should make sure that round-tripping back into HTML also works flawlessly. Otherwise, you are using a "What You See Is Not What You Get" editor, which is both less pronounceable and much less useful to your end users.

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

As you edit your document, you can see its contents change in proper WYSIWYG fashion. The document HTML is *not* automatically passed back to Swift as you make changes. You must retrieve the HTML at an appropriate place in your app using `MarkupWKWebView.getHtml()`. This leaves the question: what is "an appropriate place"? The answer is dependent on how you are using the MarkupEditor. In the demo, where you can display the HTML as you type, the HTML is retrieved at every keystroke using the `MarkupDelegate.markupInput(_:)` method. This is generally going to be a bad idea, since it makes typing much more heavyweight than it should be. You might only retrieve the edited HTML when your user presses a "Save" button. You might want to implement an autosave type of approach by tracking when changes are happening using `MarkupDelegate.markupInput(_:)`, and only invoking `MarkupWKWebView.getHtml()` when enough time has passed or enough changes have occurred.

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

You can also provide your own CSS-based style customization and JavaScript scripts for the MarkupEditor to use in your app. The CustomContentView and CustomViewController demonstrate usage of custom CSS and scripts on the `demo.html` document and are discussed below.

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

* Paragraph Styles: `<H1>`, `<H2>`, `<H3>`, `<H4>`, `<H5>`, `<H6>`, `<P>`. `<P>` is the default style, also referred to as "Normal" in various places. The `<CODE>` element is supported as a paragraph style or an inlined format. When used as a paragraph style, it is output as `<PRE><CODE>` to preserve its exact form.
* Formatting: `<STRONG>`, `<EM>`, `<U>`, `<CODE>`, `<S>`, `<SUB>`, `<SUP>`.
* Images: `<IMG class="resize-image">`. The internal details of the styling and classes to support resizable images are in `markup.js` but will not be covered here.
* Links: `<A>`.
* Lists: `<UL>`, `<OL>`, `<LI>`.
* Tables: `<TABLE>`, `<TR>`, `<TH>`, `<TD>`.
* Indenting: `<BLOCKQUOTE>`.

The MarkupEditor loads two "baseline" CSS files. The first is `mirror.css`. The styling in this file is to support the classes used by ProseMirror during editing. The second is `markup.css`, which is used to style the elements identified above as supported by the MarkupEditor. Occasionally the styles in `markup.css` will supersede the ones in `mirror.css`. 

One way to customize the MarkupEditor style is to fork the repository and edit `markup.css` to fit your needs. You can modify `mirror.css`, but you really should be familiar with ProseMirror before doing that. A less intrusive mechanism is to include your own CSS file with your app that uses the MarkupEditor, and identify the file using `MarkupWKWebViewConfiguration` that you can pass when you instantiate a MarkupEditorView or MarkupEditorUIView. The CSS file you identify this way is loaded *after* `markup.css`, so its contents follows the normal [CSS cascading rules](https://russmaxdesign.github.io/maxdesign-slides/02-css/207-css-cascade.html#/). 

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

CSS is an incredibly powerful tool for customization. The contents of `markup.css` itself are minimal but show you how the basic elements are styled by default. If there is something the MarkupEditor is doing to prevent the kind of custom styling you are after, please file an issue; however, please do not file issues with questions about CSS.

### Adding Custom Scripts

MarkupEditor functionality that modifies and reports on the state of the HTML DOM in the MarkupWKWebView is all contained in `markup.js` and should not be modified directly except for debugging purposes. Refer to the  [README](https://github.com/stevengharris/MarkupEditor/blob/main/markupeditor-js/README.md) in `markupeditor-js` for more details. 

If you have scripting you want to add, there are two mechanisms for doing so:

1. Create an array of strings that contain valid JavaScript scripts that will be loaded after `markup.js`. Pass these scripts to the MarkupEditorView or MarkupEditorUIView using the `userScripts` parameter at instantiation time.
2. Create a file containing your JavaScript code, and identify the file in your MarkupWKWebViewConfiguration.

To specify the MarkupWKWebViewConfiguration, you might hold onto it in your MarkupDelegate as `markupConfiguration = MarkupWKWebViewConfiguration()`. Assuming you created a script file called `custom.js` and packaged it as a resource with your app, specify it in the `markupConfiguration` using:

```
markupConfiguration.userScriptFile = "custom.js"
```

The `userScriptFile` is loaded after `markup.js`. Your code can use the functions in `markup.js` or which you loaded using `userScripts` if needed.

**NOTE:** Your script has access to the DOM, but you will not be able to modify the DOM directly in a user script. To be more exact: you can write code that modifies the DOM, but your changes will not be reflected in the view itself or in the document contents you retrieve using `getHtml`. This is because such changes must be done using the exported functions in `markup.js` or using the kind of ProseMirror APIs accessed from `markup.js`. Being able to add a script even within this restriction can still be very useful, however. For example, you could use a JavaScript library to return the document contents as Markdown. If you need to modify the DOM directly or otherwise interact with ProseMirror APIs, refer to the [README](https://github.com/stevengharris/MarkupEditor/blob/main/markupeditor-js/README.md) in markupeditor-js for details about how to work with the JavaScript code the Swift MarkupEditor depends on.

To invoke a function in your custom script, you should extend the MarkupWKWebView. For example, if you have a `custom.js` file that contains this function:

```
/**
 * A public method that can be invoked from MarkupWKWebView to return
 * the number of words in the HTML document using a simpleminded approach.
 * Invoking this method requires an extension to MarkupWKWebView.
 */
MU.wordCount = function() {
    let wordCount = 0;
    const styles = ['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'CODE'];
    for (const style of styles) {
        const elements = document.querySelectorAll(style);
        for (const element of elements) {
            wordCount += element.textContent.trim().split(' ').length;
        }
    };
    return wordCount;
};
```

then you can extend MarkupWKWebView to be able to invoke `MU.wordCount`:

```
extension MarkupWKWebView {
    
    /// Invoke the MU.wordcount method on the JavaScript side that was added-in via custom.js.
    public func wordcount(_ handler: ((Int?)->Void)? = nil) {
        evaluateJavaScript("MU.wordCount()") { result, error in
            if let error {
                print(error.localizedDescription)
            }
            handler?(result as? Int)
        }
    }
    
}
```

The CustomContentView and CustomViewController demos use this approach along with `custom.css` to modify the styling of some elements and to display a word count in the demo. This is a contrived use case, but it demonstrates how to use custom scripting and CSS.

### Adding Resources From Your App

The MarkupEditor knows to pull-in certain resources from your app when you identify them using `userCssFile` or `userScriptFile`. When you identify CSS and scripts in this way, the files are co-located with the document you are editing when it is opened. However, you may have additional resources you also want to pull-in. You can do this by passing the file names in `userResourceFiles` in MarkupWKWebViewConfiguration. 

To specify the MarkupWKWebViewConfiguration, you might hold onto it in your MarkupDelegate as `markupConfiguration = MarkupWKWebViewConfiguration()`. Assuming you have an image called `myImage.png` and packaged it as a resource with your app, specify it in the `markupConfiguration` using:

```
markupConfiguration.userResourceFiles = ["myImage.png"]
```

You can add as many resources as you want to the `userResourceFiles` array.

## Local Images

Being able to insert an image into a document you are editing is fundamental. In Markdown, you do this by referencing a URL, and the URL can point to a file on your local file system. The MarkupEditor can do the same, of course, but when you insert an image into a document in even the simplest WYSIWYG editor, you don't normally have to think, "Hmm, I'll have to remember to copy this file around with my document when I move my document" or "Hmm, where can I stash this image so it will be accessible across the Internet in the future."  From an end-user perspective, the image is just part of the document. Furthermore, you expect to be able to paste images into your document that you copied from elsewhere. Nobody wants to think about creating and tracking a local file in that case.

The MarkupEditor refers to these images as "local images", in contrast to images that reside external to the document. Both can be useful! When you insert a local image (by selecting it from the Image Toolbar or by pasting it into the document), the MarkupEditor creates a _new_ image file using a UUID for the file name. By default, that file resides in the same location as the text you are editing. For the demos, the document HTML and local image files are held in an `id` subdirectory of the URL found from `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)`. You can pass the `id` to your `MarkupWKWebView` when you create it - for example, it might be the name of the document you're editing. When the MarkupEditor creates a new local image file, your `MarkupDelegate` receives a notification via the `markupImageAdded(url: URL)` method, giving you the URL of the new local image.

Although local image support was a must-have in my case, it seems likely some MarkupEditor consumers would feel like it's overkill or would like to preclude its use. It also requires you to do something special with the local images when you save your document. For these reasons, there is an option to control whether to allow selection of images from local files. Local images are disallowed by default. To enable them, specify `MarkupEditor.allowLocalImages = true` early in your application lifecycle. This will add a Select button to the `ImageViewController`.

A reminder: The MarkupEditor does not know how/where you want to save the document you're editing or the images you have added locally. This is the responsibility of your app.

## Search

This section addresses searching within the document you are editing using the MarkupEditor but also provides some guidance on searching for the documents you create or edit using MarkupEditor.

### Searching Within A Document

For many applications, you will have no need to search the content you are editing in the MarkupEditor. But when content gets larger, it's very handy to be able to find a word or phrase, just like you would expect in any text editor. The MarkupEditor supports search with the `MarkupWKWebView` function:

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

The SwiftUI demo (*not the UIKitDemo*) includes a `SearchableContentView` that uses a `SearchBar` to invoke search on `demo.html`. The `SearchBar` is not part of the MarkupEditor library, since it's likely most users will implement search in a way that is specific to their app. For example, you might use the `.searchable` modifier on a NavigationStack. You can use the `SearchBar` as a kind of reference implementation, since it also demonstrates the use of "search mode" by specifying `activate: true` when you submit text in the `SearchBar's` TextField.

### Searching for MarkupEditor Documents

You can use CoreSpotlight to search for documents created by the MarkupEditor. That's because CoreSpotlight already knows how to deal properly with HTML documents. To be specific, this means that when you put a table and image in your document, although the underlying HTML contains `<table>` and `<img>` tags, the indexing works on the DOM and therefore only indexes the text content. If you search for "table" or "img", it won't find your document unless there is a text element containing the word "table" or "image".

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

There are two test targets.

The `BaseTests` target covers all the functionality of the MarkupEditor that is present in markupeditor-base and exposed in the Swift MarkupEditor. With the exception of image pasting, `BaseTests` covers everything that is accessible via the MarkupToolbar across a variety of text and selections. The BaseTests use Swift Testing parameterized tests to exercise each test that is defined in a test suite `.json` file from the markupeditor-base project. Each test that performs an action also tests the undo and redo of that action and validates the selection after each operation. The tests take less than 30 seconds when there are no errors.

The `SwiftTests` target covers functionality that is specific to the Swift MarkupEditor which is not present in markupeditor-base. The only test currently ensures that pasting of [Local Images](#local-images) into the MarkupEditor produces a uniquely named local file in the document directory.

## Demos

If you consume just the package, you don't get the demo targets to build. If you create a workspace that contains the MarkupEditor project or just clone this repository, you will also get the two demo targets, creatively named `SwiftUIDemo` and `UIKitDemo`. There is also a MarkupEditor framework target in the project that is 100% the equivalent of the Swift package. By default, the demos both consume the framework, because I found it to be a lot less hassle when developing the project in the early stage. The only difference between consuming the framework and the Swift package is how the `MarkupWKWebView` locates and loads its `markup.html` resource when it is instantiated.

The demos open `demo.html`, which contains information about how to use the MarkupEditor as an end user and shows you the capabilities. They populate the `leftToolbar` of the MarkupToolbar to include a `FileToolbar` that lets you create a new document for editing or open an existing HTML file. The `DemoContentView` (or `DemoViewController` in the UIKitDemo) acts both as the `MarkupDelegate` and the `FileToolbarDelegate`. As the `FileToolbarDelegate`, it opens a `TextView` to display the underlying raw HTML, which is nice for demo. The raw HTML updates as you type and make changes to the document, which is fun and has been helpful for debugging; however, you probably don't want to be doing heavyweight things like that for every keystroke in a real app.

The demo directories also contain a "Simplest" version of a SwiftUI View and UIKit UIViewController, since the `DemoContentView` and `DemoViewController` for the demos are more complex, with pickers and the raw HTML display brought in with the `FileToolbar`, and the support for selecting local images. If you want to try the "Simplest" versions out, just edit the `SceneDelegate` to point at the `SimplestContentView` or `SimplestViewController`.

As discussed in the [Searching Within A Document](#searching-within-a-document) section, a SwiftUI `SearchableContentView` is also provided to demonstrate the ability to search within a MarkupEditor HTML document, along with a `SearchBar` to invoke the functionality.

## Status

The current version is a feature-complete Beta. I am now consuming it myself in another project I am developing, so changes are being driven primarily by MarkupEditor uptake in that project (and any issues people might raise).

### Known Issues

[Issues](https://github.com/stevengharris/MarkupEditor/issues) are being tracked on GitHub.

### History

History is now being tracked in a separate [Change Log](https://github.com/stevengharris/MarkupEditor/blob/main/CHANGELOG.md)

## Legacy and Acknowledgements

The MarkupEditor uses the excellent [ProseMirror](https://prosemirror.net) to do the heavy lifting related to WYSIWYG editing. I don't think ProseMirror existed when I first began the MarkupEditor, but I wish it had, and that I had the sense to use it. Today ProseMirror is a mature product with many users, first-class documentation, and an active and helpful [forum](https://discuss.prosemirror.net). To quote from the ProseMirror site:

> ProseMirror is [open source](https://github.com/ProseMirror/prosemirror/blob/master/LICENSE), and you are legally free to use it commercially. Yet, writing, maintaining, supporting, and setting up infrastructure for such a project takes a lot of work and energy. Therefore...

> **If you are using ProseMirror to make profit, there is a social expectation that you help fund its maintenance. [Start here](http://marijnhaverbeke.nl/fund/).**

I encourage MarkupEditor users to take these statements to heart. The MarkupEditor itself is a decent size project, but by adopting ProseMirror, the JavaScript written to support this project went from over 11,000 lines to around 3,000 lines, and the most complex code for things like undo/redo just disappeared completely.

When I started my search for an open source "Swift WYSIWYG editor", I found a kind of mishmash of things. The [RichEditorView](https://github.com/cjwirth/RichEditorView) was one of the most visible. The RichEditorView was originally built using UIWebView, which has long been deprecated. A couple of people had [forked](https://github.com/cbess/RichEditorView/) and [ported](https://github.com/YoomamaFTW/RichEditorView) it to WKWebView and shared their work. I used that for a while in some work I was doing, but I kept hitting edges and felt like I was having to put a lot of work into a fork that would never really see the light of day. The thought of moving the result into SwiftUI was making me queasy. The MarkupEditor is meant to be a proper "modern" version for WYSIWYG editing you can use in your SwiftUI or UIKit project, but it was hatched in the original RichEditorView.

The MarkupEditor's original approach of directly modifying the HTML DOM containing a `contentEditable` DIV under the covers seems like a good idea until you read Nick Santos' article about [Why ContentEditable is Terrible](https://medium.engineering/why-contenteditable-is-terrible-122d8a40e480). His main arguments center around WYSIWYG, and the meaning of the term when editing a document in this way. In the simplest case, consider if you save the HTML you edited using the MarkupEditor and then use a different CSS to display it in a different browser. What you saw when you edited will certainly not be what you get. The text content will be 100% the same, of course. If what you are editing and saving remains in the same HTML form and is presented using the same CSS using a WKWebView, then it will be WYSIWYG. In any case, you need to think about it when adopting this approach. 

The original MarkupEditor had the advantage of not supporting arbitrary HTML. In fact, it owned the definition of the exact subset of HTML that was allowed. (In ProseMirror, this is formalized using its [Schema](https://prosemirror.net/docs/ref/#model.Document_Schema).) The MarkupEditor is targeted only at WKWebView, so there are no browser portability problems. The restrictions on functionality and the absence of styling elements from the HTML helped avoid some of the problems cited in [Nick's article](https://medium.engineering/why-contenteditable-is-terrible-122d8a40e480). Also, by avoiding use of (the now deprecated but likely to live forever) [Document.execCommand](https://developer.mozilla.org/en-US/docs/Web/API/Document/execCommand) to perform editing tasks against the DOM, the original MarkupEditor avoided WebKit polluting the "clean" HTML with spans and styles. These issues go away with ProseMirror, because its Schema captures exactly what elements are allowed, how they are transformed into ProseMirror [Nodes](https://prosemirror.net/docs/ref/#model.Node), and how they present themselves in the DOM.

In case you think "To heck with this contentEditable nonsense. How hard can it be to build a little editor!?", I refer you to this [article on lord.io](https://lord.io/text-editing-hates-you-too/). The DOM and its incredibly well-documented API are proven and kind of amazing, even if `contenteditable` itself is a kind of dumpster fire. To be able to ride on top of the work done in the browser is a gift horse that should not be looked in the mouth.

## License

MarkupEditor is available under the [MIT license](https://github.com/stevengharris/MarkupEditor/blob/main/LICENSE).

MarkupEditor depends on ProseMirror (https://prosemirror.net, https://github.com/prosemirror). Be aware that if you distribute MarkupEditor or embed it in your application, you will be distributing `markup.js`, which in addition to original MarkupEditor code, contains "substantial portions" of ProseMirror. ProseMirror is also available under the [MIT license](https://github.com/ProseMirror/prosemirror/blob/master/LICENSE).
