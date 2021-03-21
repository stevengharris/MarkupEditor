# MarkupEditor

WYSIWYG editing for SwiftUI and UIKit apps

Copyright © 2021 Steven Harris. All rights reserved.

Jealous of those JavaScript coders with their WYSIWYG text editors, but just can't stomach the idea of immersing yourself in JavaScript when you're enjoying the comfort and joy of Swift? Yeah, me too. When you search "Swift WYSIWYG editor", you find a kind of mishmash of things. The [RichEditorView](https://github.com/cjwirth/RichEditorView) is one of the most visible. The RichEditorView was originally built using UIWebView, and then it was [forked](https://github.com/cbess/RichEditorView/) and [ported](https://github.com/YoomamaFTW/RichEditorView) to WKWebView in sort-of working form. I used it for a while in some work I was doing, but I kept hitting edges and felt like I was having to put a lot of work into a fork that would never really see the light of day. The thought of moving the result into SwiftUI was making me queasy. The MarkupEditor is a proper "modern" version for WYSIWYG editing that you can consume and use in your SwiftUI or UIKit project.

## HTML As An Intermediate Form

The MarkupEditor is presenting an HTML document to you as you edit. It uses the capabilities of HTML, CSS, and JavaScript to change the underlying DOM as you edit. In iOS or on the Mac, this is presented to you natively as a MarkupWKWebView, a subclass of WKWebView. The MarkupEditor does not know how to save your document or transform it to some other format. This is something your application that consumes the MarkupEditor will need to do. The MarkupEditor will let your MarkupDelegate know as the underlying document changes state, and you can take advantage of those notifications to save and potentially transform the HTML into another form. If you're going to do that, then you should make sure the round-tripping also works flawlessly. Otherwise, you are using a "What You See Is Not What You Get" editor, which is both less pronounceable and much less useful to your end users.

### Markdown As The Source Of Truth

My goal in creating the MarkupEditor is to provide WYSIWYG editing for Markdown. You might find yourself asking: "Does that even make sense?" I wanted to do this because I want them to have a great editing experience, but I don't want to have to learn Markdown. The choice of Markdown as source of truth is something I want and which my users will generally not be aware of. I want the documents they are editing and creating to be captured in Markdown so that they will still end up with a reasonable text file that they can use if they're not using my tool. 

What does it mean to use Markdown as the source of truth? If you don't support arbitrary HTML insertion into the Markdown, then it means a lot of what you can do is a subset of what you might expect in a general WYSIWYG editor. For example, Markdown doesn't have a way for you to say "My H1 is 30 points, and H2 is 24 points." The choice of how to display a header is up to the html and css styling in your browser. You can't change character sizes in the middle of a paragraph in Markdown, but you can certainly do that in HTML. There is no native Markdown way to specify colored text. If you're just authoring text - which is what Markdown is for - then that stuff is all a distraction. What this means from a UX standpoint in the MarkupEditor is that it is restricted to Markdown-type functionality. For example, the toolbar provides no way to select colors or font sizes.

## Status

The current version is very much a work in progress. I am using a [separate GitHub project](https://github.com/stevengharris/MarkupEditorDemo) to flesh out both a SwiftUI-based demo and a UIKit-based demo. They both consume the same MarkupEditor Swift package.
