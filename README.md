# MarkupEditor

WYSIWYG editing for SwiftUI and UIKit apps

Copyright © 2021 Steven Harris. All rights reserved.

Jealous of those JavaScript coders with their WYSIWYG text editors, but just can't stomach the idea of immersing yourself in JavaScript when you're enjoying the comfort and joy of Swift? Yeah, me too. So when I was forced to do it, I thought I'd share what I did as a way to help others avoid it.

## HTML As An Intermediate Form

The MarkupEditor is presenting an HTML document to you as you edit. It uses the capabilities of HTML, CSS, and JavaScript to change the underlying DOM as you edit. In iOS or on the Mac, this is presented to you natively as a MarkupWKWebView, a subclass of WKWebView. The MarkupEditor does not know how to save your document or transform it to some other format. This is something your application that consumes the MarkupEditor will need to do. The MarkupEditor will let your MarkupDelegate know as the underlying document changes state, and you can take advantage of those notifications to save and potentially transform the HTML into another form. If you're going to do that, then you should make sure the round-tripping also works flawlessly. Otherwise, you are using a "What You See Is Not What You Get" editor, which is both less pronounceable and much less useful to your end users.

### Markdown As The Source Of Truth

My goal in creating the MarkupEditor was to provide WYSIWYG editing for Markdown. You might find yourself asking: "Does that even make sense?" I wanted to do this because I want my users to have a great editing experience, but I don't want them to have to learn Markdown and look at all the Markdown cruft as they write. The choice of Markdown as source of truth is something I want, but which my users will generally not be aware of. I want the documents they are editing and creating to be captured in Markdown so that they will still end up with a reasonable text file that they can use if they're not using my tool. 

What does it mean to use Markdown as the source of truth? If you don't support arbitrary HTML insertion into the Markdown, then it means a lot of what you can do is a subset of what you might expect in a general WYSIWYG editor. For example, Markdown doesn't have a way for you to say "My H1 is 30 points, and H2 is 24 points." The choice of how to display a header is up to the html and css styling in your browser or your Markdown renderer. You can't change character sizes in the middle of a paragraph in Markdown, but you can certainly do that in HTML. There is no native Markdown way to specify colored text. If you're just authoring text - which is what Markdown is for - then that stuff is all a distraction. What this means from a UX standpoint in the MarkupEditor is that it is restricted to Markdown-type functionality. For example, the toolbar provides no way to select colors or font sizes.

## Status

The current version is very much a work in progress. The work is a back-and-forth between the MarkupEditor package proper and the two demos. If you consume just the package, you don't get the demos. If you create a workspace that contains the MarkupEditor project or just clone this repository, you will also get the two demo targets, creatively named SwiftUIDemo and UIKitDemo. There is also a MarkupEditor framework target in the project that is 100% the equivalent of the Swift package. By default, the demos both consume the framework, because I find it to be a lot less hassle when developing the project overall, especially in the early stage. The only difference between consuming the framework and the Swift package is how the MarkupWKWebView locates and loads its `markup.html` resource when it is instantiated.

## Legacy and Acknowledgements

When I started my search for a "Swift WYSIWYG editor", I found a kind of mishmash of things. The [RichEditorView](https://github.com/cjwirth/RichEditorView) was one of the most visible. The RichEditorView was originally built using UIWebView, which has long been deprecated. A couple of people [forked](https://github.com/cbess/RichEditorView/) and [ported](https://github.com/YoomamaFTW/RichEditorView) it to WKWebView and shared their work. I used that for a while in some work I was doing, but I kept hitting edges and felt like I was having to put a lot of work into a fork that would never really see the light of day. The thought of moving the result into SwiftUI was making me queasy. The MarkupEditor is meant to be a proper "modern" version for WYSIWYG editing you can use in your SwiftUI or UIKit project, but it was hatched in the original RichEditorView.

