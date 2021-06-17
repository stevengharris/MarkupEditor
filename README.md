# MarkupEditor

WYSIWYG editing for SwiftUI and UIKit apps

Copyright © 2021 Steven G. Harris. All rights reserved.

Jealous of those JavaScript coders with their WYSIWYG text editors, but just can't stomach the idea of immersing yourself in JavaScript when you're enjoying the comfort and joy of Swift? Yeah, me too. So when I was forced to do it, I thought I'd share what I did as a way to help others avoid it.

## HTML And JavaScript In The Back, Swift in the Front

The MarkupEditor is presenting an HTML document to you as you edit. It uses the capabilities of HTML, CSS, and JavaScript to change the underlying DOM as you edit. In iOS or on the Mac, this is presented to you natively as a MarkupWKWebView, a subclass of WKWebView. The MarkupEditor does not know how to save your document or transform it to some other format. This is something your application that consumes the MarkupEditor will need to do. The MarkupEditor will let your MarkupDelegate know as the underlying document changes state, and you can take advantage of those notifications to save and potentially transform the HTML into another form. If you're going to do that, then you should make sure that round-tripping back into HTML also works flawlessly. Otherwise, you are using a "What You See Is Not What You Get" editor, which is both less pronounceable and much less useful to your end users.

### Markup Editor Goals and Non-Goals

I am working on a larger project that requires embedded support "rich text" editing. I felt like WYSIWYG editing was a must-have requirement. I could have forced my developer-users to use Markdown, but I find it to be annoying both to write and to look at while writing. Who wants to have to mentally filter all that cruft on the screen. It's a lot better than editing raw HTML, but come on, this is the 21st century. Having to deal with an editing experience where you use some kind of preview mode to make sure what you are writing will be presented like you expect feels like CI/CD for writing. 

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
* Centering
* Copy/paste preserving formatting of rich text or HTML

If you want a richer feature set, you can extend the MarkupEditor to do these yourself. The demos include examples of how to extend the MarkupEditor's core features and how to interact with the file system for saving what you edit. It's my intent to keep the core MarkupEditor feature set to be similar to what you will see in GitHub Markdown.

## Consuming the MarkupEditor

## Code Structure

## Status

The current version is very much a work in progress. The work is a back-and-forth between the MarkupEditor package proper and the two demos. If you consume just the package, you don't get the demos. If you create a workspace that contains the MarkupEditor project or just clone this repository, you will also get the two demo targets, creatively named SwiftUIDemo and UIKitDemo. There is also a MarkupEditor framework target in the project that is 100% the equivalent of the Swift package. By default, the demos both consume the framework, because I find it to be a lot less hassle when developing the project overall, especially in the early stage. The only difference between consuming the framework and the Swift package is how the MarkupWKWebView locates and loads its `markup.html` resource when it is instantiated.

## Legacy and Acknowledgements

When I started my search for a "Swift WYSIWYG editor", I found a kind of mishmash of things. The [RichEditorView](https://github.com/cjwirth/RichEditorView) was one of the most visible. The RichEditorView was originally built using UIWebView, which has long been deprecated. A couple of people [forked](https://github.com/cbess/RichEditorView/) and [ported](https://github.com/YoomamaFTW/RichEditorView) it to WKWebView and shared their work. I used that for a while in some work I was doing, but I kept hitting edges and felt like I was having to put a lot of work into a fork that would never really see the light of day. The thought of moving the result into SwiftUI was making me queasy. The MarkupEditor is meant to be a proper "modern" version for WYSIWYG editing you can use in your SwiftUI or UIKit project, but it was hatched in the original RichEditorView.

