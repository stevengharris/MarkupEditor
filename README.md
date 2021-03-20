# MarkupEditor

WYSIWYG editing of Markdown and HTML for SwiftUI and UIKit apps
Copyright © 2021 Steven Harris. All rights reserved.

Jealous of those JavaScript coders with their WYSIWYG text editors, but just can't stomach the idea of immersing yourself in JavaScript when you're enjoying the comfort and joy of Swift? Yeah, me too. When you search "Swift WYSIWYG editor", you find a kind of mishmash of things. The RichTextEditor is one of the most visible. The RichTextEditor was originally built for UIWebView, and then it was forked and ported to WKWebView in sort-of working form. I used it for a while in some work I was doing, but I kept hitting edges and felt like I was having to out a lot of work into a fork that would never really see the light of day. The thought of moving the result into SwiftUI was making me queasy. The MarkupEditor is a proper "modern" version for WYSIWYG editing that you can consume and use in your SwiftUI or UIKit project.

## Markdown or HTML?

My goal is to provide WYSIWYG editing for Markdown. As you edit text, bold/italicize words, specify headers, and link to things, I want the result to be captured in Markdown, not in HTML. I want Markdown to be the source of truth for what I am editing and viewing. Why? Markdown is easy to edit if you just have the raw text, whereas HTML is a nightmare. At the same time, I want to be doing true WYSIWYG editing and not have to look at all the Markdown cruft. Sure, it's a million times better than having to edit HTML, but I want my end users to just edit like they're used to - with a toolbar, hotkeys, and instant feedback as they type. [Links](https://github.com/stevengharris/MarkupEditor) should look like links, and when you click on them, you should see what they link-to in your browser.

What does it mean to use Markdown as the source of truth? If you don't support arbitrary HTML insertion into the Markdown, then it means a lot of what you can do is a subset of what you might expect in a general WYSIWYG editor. For example, Markdown doesn't have a way for you to say "My H1 is 30 points, and H2 is 24 points." The choice of how to display a header is up to the html and css styling in your browser. You can't change character sizes in the middle of a paragraph in Markdown, but you can certainly do that in HTML. There is no native Markdown way to specify colored text. If you're just authoring text - which is what Markdown is for - then that stuff is all a distraction. What this means from a UX standpoint in the MarkupEditor is that it is restricted to Markdown-type functionality. For example, the toolbar provides no way to select colors or font sizes.

## Status

The current version is very much a work in progress. I am using a [separate GitHub project](https://github.com/stevengharris/SwiftMarkupEditor) to flesh out a SwiftUI-based demo and a UIKit-based demo. They both consume the same MarkupEditor Swift package.
