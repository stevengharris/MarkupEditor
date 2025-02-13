# Working in JavaScript with the MarkupEditor

This file documents how to make changes to `markup.js` and other files that work with the [ProseMirror API](https://prosemirror.net/docs/ref/) to modify the DOM displayed in the MarkupWKWebView. You should be familier with the MarkupEditor itself, especially the content in the [README](https://github.com/stevengharris/MarkupEditor/blob/main/README.md). You will also need to understand ProseMirror itself. The best place to start is the [ProseMirror Guide](https://prosemirror.net/docs/guide/). This document will refer to MarkupEditor concepts like MarkupToolbar and MarkupDelegate, and ProseMirror concepts like EditorState and Schema with little to no explanation of what they mean.

## Background

The MarkupEditor has some reasonable built-in mechanisms for customization. These mechanisms are intended to help avoid forking the repository just to get the presentation or behavior you need within your Swift app. For example, you can modify the contents and presentation in the MarkupToolbar, and you can override the callbacks made to your MarkupDelegate to customize behavior. You can add your own css and control the styling of the MarkupWKWebView, and you can load your own JavaScript scripts into it that you can invoke from Swift. These mechanisms are documented in the README in the expectation that many users will need them at some point.

Some users will want to dig deeper or will need to modify the JavaScript code that is modifying the document in the MarkupWKWebView as you edit. This document describes how to do that. In earlier versions of the MarkupEditor, the answer was basically: modify `Resources/markup.js`. The answer is no longer that simple because `Resources/markup.js` is now a build artifact produced using [rollup](https://rollupjs.org). The build now uses `rollup` to combine a smaller `markup.js` and other code that uses [ProseMirror](https://prosemirror.net) to do the heavy lifting in WYSIWYG editing.

## Requirements

There are many tools to help you do combined Swift and JavaScript development, which is what is required here. I'm only going to describe the specifics of the environment I use to work on the MarkupEditor using Xcode and VSCode.

You will need [node.js and npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm), and you will need [rollup](https://rollupjs.org) installed. You'll be using rollup as a command line tool. I did the work described here using XCode 16.2, VSCode 1.97.0, node.js/npm v20.17.0, and rollup 10.7.0. If you're using different versions, you may encounter the usual JavsScript version mismatch issues. In that case, I can only sympathize and wish you luck sorting them out.

## Setting Up

Clone the [MarkupEditor repository](https://github.com/stevengharris/MarkupEditor.git). Move to `MarkupEditor/rollup` and install the dependencies using npm:

```
$ git clone https://github.com/stevengharris/MarkupEditor.git
Cloning into 'MarkupEditor'...
remote: Enumerating objects: 5447, done.
remote: Counting objects: 100% (752/752), done.
remote: Compressing objects: 100% (148/148), done.
remote: Total 5447 (delta 664), reused 636 (delta 603), pack-reused 4695 (from 2)
Receiving objects: 100% (5447/5447), 7.04 MiB | 14.90 MiB/s, done.
Resolving deltas: 100% (3703/3703), done.
$ cd MarkupEditor/MarkupEditor/rollup/
$ npm install

added 42 packages, and audited 43 packages in 877ms

found 0 vulnerabilities
$ 
```

The `npm install` step populates the `node_modules` needed to produce the `markup.js` that is eventually loaded into the MarkupEditor.

## Combined Swift+JavaScript Build and Development Flow

First, some background on the MarkupEditor build and what happens to JavaScript at runtime. Then we'll take a look at the contents of `rollup/src/js` where the MarkupEditor JavaScript source lives, and how that is used to produce `Resources/markup.js`.

### Xcode Build and MarkupEditor Runtime Operations

The MarkupEditor proper only has one Xcode/SPM build target, which is the `MarkupEditor` framework target. For development purposes, there are three more targets:

* BasicTests - A set of tests each of which executes multiple tests defined using `HtmlTest.swift`.
* SwiftUIDemo - An iOS or MacCatalyst app built using SwiftUI to demo the MarkupEditor.
* UIKitDemo - An iOS or MacCatalyst app built using UIKit to demo the MarkupEditor.

There are variations of demos available also, such as SearchableContentView for SwiftUI. The demos generally load `demo.html`, which contains all the elements supported by the MarkupEditor. If you make JavaScript or Swift changes, you can almost always use the demo code to ensure things work correctly without the complications of your own app. You can use BasicTests to ensure that you haven't introduced a regression. The BasicTests are good at exercising the functionality you can visualize from the MarkupToolbar, but frankly, a lot of user interaction within the editor is not very practical to test in an automated fashion IMO.

As described in the README, when the MarkupEditor loads the MarkupWKWebView, it locates `markup.html` that (during development) resides in the `Resources` directory. The `markup.html` file identifies the `markup.js` script. The `markup.js` script contains all the JavaScript code to do WYSIWYG editing of the document and call back into Swift. The `markup.html` file also identifies `mirror.css` and `markup.css` that are used to style the HTML content you load-in and edit. The loading flow can include your own scripts and css, as discussed in the README. 

> The main topic of this document is: How to create the `Resources/markup.js` script that the MarkupEditor loads at runtime. That file is produced using rollup from the contents of the `MarkupEditor/rollup` directory.

### JavaScript Build

The `rollup/package.json` file defines the build and commands to produce the `Resources/markup.js` file that is loaded by the MarkupEditor at runtime. Invoking `npm run build` from the `MarkupEditor/rollup` directory causes `rollup` to be executed using the configuration in `rollup.config.mjs`. The configuration identifies the kind of output that is produced: a browser-loadable JavaScript module, `dist/markupmirror.umd.js`. After the build produces this file, the post-build step in `package.json` copies it to `Resources/markup.js`.

```
$ npm run build

> rollup-markupmirror@1.0.0 build
> rollup -c

(node:32487) ExperimentalWarning: Importing JSON modules is an experimental feature and might change at any time
(Use `node --trace-warnings ...` to show where the warning was created)

src/js/main.js → dist/markupmirror.umd.js...
created dist/markupmirror.umd.js in 748ms

> rollup-markupmirror@1.0.0 postbuild
> cp -f dist/markupmirror.umd.js ../Resources/markup.js

$
```

At this point, you have a new `MarkupEditor/Resources/markup.js` that replaced the original one in the repository.

#### What's That Warning?

The `ExperimentalWarning` is a byproduct of this import in `rollup.config.mjs`:

```
import pkg from './package.json' with { type: "json" };
```

The import causes an error without `with { type: "json" }` and the ominous warning with it. I can only say: Welcome to the world of JavaScript modules. If you're a JavaScript noob wondering what the heck a UMD file is and why rollup is being used here, you might find both of these articles to be helpful: [Part 1](https://www.freecodecamp.org/news/javascript-modules-a-beginner-s-guide-783f7d7a5fcc) and [Part 2](https://www.freecodecamp.org/news/javascript-modules-part-2-module-bundling-5020383cf306). Suffice it to say here that `rollup.config.mjs` tells rollup to take input from `src/js/main.js`, which is the starting point to build everything on the JavaScript side.

### Summary of Development Flow

I keep both Xcode and VSCode open. I use the terminal window in VSCode from the `MarkupEditor/rollup` directory to invoke `npm` on the command line. The Xcode project includes files in the `MarkupEditor/rollup` directory, but I have VSCode open on that directory and use VSCode to do JavaScript coding. The MarkupEditor git repository excludes the `MarkupEditor/rollup/node_modules` and `MarkupEditor/rollup/dist` directories.

* After you modify code in `MarkupEditor/rollup/src/js`, rebuild `Resources/markup.js` by invoking:

```
npm run build
```

* Build the MarkupEditor framework in Xcode using the `MarkupEditor` target. Alternatively, launch the SwiftUIDemo or the UIKitDemo target (or your own Xcode target that depends on the MarkupEditor), which will load the newly built `Resources/markup.js` and exercise your JavaScript code.

Note that it's easy to forget to run `npm run build` after making a JavaScript change, which in turn leaves you wondering why your change didn't make any difference. If you find this happening too often, you can consider putting a pre-build step in Xcode to always run `npm run build` (since it's fast anyway). I don't do that myself, but it seems worthwhile to point out as an option.

## Key Files in `MarkupEditor/rollup/src/js`

All the MarkupEditor-specific JavaScript source code is held within `rollup/src/js`. One of rollup's key features is [tree-shaking](https://rollupjs.org/faqs/#what-is-tree-shaking), ensuring that only code used by the MarkupEditor is included. So, while it's possible that `rollup/src/js` contains code that is not reachable from the MarkupEditor, rollup ensures that only code reachable from `src/js/main.js` is included in the final `dist/markupmirror.umd.js` which is copied into `Resources/markup.js`. The rollup-produced code in `Resources/markup.js` is still readable and debuggable and includes comments.

The structure and some naming in `MarkupEditor/rollup/src/js` are adapted from a [ProseMirror starter kit](https://github.com/mfoitzik/prosemirror-breakout-starter-kit). Although the ProseMirror site provides quite a few [examples](https://prosemirror.net/examples/) and even an [example setup package](https://github.com/prosemirror/prosemirror-example-setup), it's still a challenge to get your head wrapped around. This particular [starter kit](https://github.com/mfoitzik/prosemirror-breakout-starter-kit) was a bit out of date and used `webpack` when I wanted to use `rollup`, but I appreciated his explanation of what he had done. In this section, I'm referring to file names and directories relative to `MarkupEditor/rollup/src/js`.

### `main.js`

Everything starts at `main.js`. It creates the ProseMirror EditorView with an initial EditorState based on the Schema defined in `schema/index.js`. The EditorState includes a set of MarkupEditor-specific Plugins defined in `setup/index.js`. The view includes MarkupEditor-specific NodeViews defined in `markup.js`. It also includes special handling of some events to notify the Swift side of state changes. It's important to note that `main.js` specifies - in its exports - what the MarkupEditor public API is for calls from Swift to JavaScript.

### `markup.js`

This is the heart of the MarkupEditor integration between Swift and ProseMirror. The exported functions are invoked from the MarkupWKWebView with the prefix `MU`. For example, the JavaScript function to toggle the current selection to bold:

```
export function toggleBold() {
    _toggleFormat('B');
};
```

is invoked from the MarkupWKWebView as:

```
public func bold(handler: (()->Void)? = nil) {
    evaluateJavaScript("MU.toggleBold()") { result, error in
        handler?()
    }
}
```

Note that the exported functions in `markup.js` do not comprise the JavaScript API that is accessible from Swift. The exports in `main.js` define the JavaScript API that is accessible from Swift.

Included in `markup.js` are two ProseMirror NodeViews: `ImageView` and `DivView`. NodeViews provide special handling when rendering a ProseMirror Node. For example, the `ImageView` lets us handle image resizing in the MarkupEditor using a combination of CSS styling of resize handles and the logic in the `ResizableImage` class defined in `markup.js`.

### `setup/index.js`

The `setup/index.js` file defines and returns the set of ProseMirror Plugins used by the MarkupEditor. These plugins are loaded from `main.js`. The plugins are commented reasonably well, but details of the code and, well, what a ProseMirror Plugin is, are beyond the scope of this document.

### `setup/keymap.js`

Sets up the keymapping/hotkeys for the MarkupEditor. Generally the key mappings are the same as used in the `prosemirror-example-setup`, but also include list handling and table selection/navigation. The MarkupEditor also chains commands to `Enter` and `Delete` that invoke `stateChanged` (and potentially search) as needed.

### `schema/index.js`

From the ProseMirror [Reference manual](https://prosemirror.net/docs/ref/):

> Every ProseMirror document conforms to a schema, which describes the set of nodes and marks that it is made out of, along with the relations between those, such as which node may occur as a child node of which other nodes.

Basically, if it's not defined in the schema, then it cannot exist in a MarkupEditor document. For example, if you attempt to load HTML containing SPAN elements, they will be ignored. (This is not strictly true, since the MarkupEditor preprocesses HTML to extract SPAN contents that will be recognized by the MarkupEditor as defined in the Schema.) The end result is that MarkupEditor only produces "clean" HTML documents, not ones littered with SPANS and styles. You can paste from an HTML page in your browser, which often contains gnarly HTML because of whatever the web site used to produce it, but it will be brought into the MarkupEditor containing only the elements defined in the schema.

This file defines the Schema for the MarkupEditor. It's similar to the `prosemirror-example-setup`, but includes such things as DIV and BUTTON to support the MarkupEditor usage of multiple contenteditable divs [discussed here](https://github.com/stevengharris/MarkupEditor/discussions/178).

### Menu-related Source

The `rollup/src/js` directory includes contents related to the menubar and menu. This code supports editing within the browser itself, rather than from Swift. I've left it in place for two reasons. First, it has been useful for debugging, and second, I may use it in the future. If you want to see it, you can enable the menubar by passing `menubar: true` to `markupSetup` in `main.js`:

```
EditorState.create({
    doc: DOMParser.fromSchema(muSchema).parse(document.querySelector("#editor")),
    plugins: markupSetup({
      menuBar: false,   // <- Change to true to show the ProseMirror menubar
      schema: muSchema
    })
})
```

## Debugging

I use the [Safari Web Inspector](https://developer.apple.com/documentation/safari-developer-tools/web-inspector) for debugging JavaScript code. Swift developers may not even be aware of its capabilities. If you have not enabled it before, in Safari -> Settings -> Advanced, check the "Show features for web developers" checkbox. This should add a Develop menu in Safari, which displays among other items a list of devices displaying web views that can be inspected. (You'll see Xcode there if you have the help section opened on the right, since that is an embedded web view!) When you're running an application displaying a MarkupWKWebView, like SwiftUIDemo on your Mac or iPhone or in the simulator, the app will show up in the Develop menu under the device it is running on. Select the app, and the Safari Web Inspector will open. You can see what scripts are loaded, set breakpoints, see the DOM, and check out how CSS styling is working among many other things. 

Note that the MarkupEditor sets `isInspectable` to `true` for the MarkupWKWebView in DEBUG builds. This had been necessary to use the Safari Web Inspector since iOS 16.4. The default is `false`, so you (and your users) won't be able to inspect non-DEBUG builds or your production app.

A debugging cycle often consists of:

* Launch the app.
* Open the Safari Web Inspector on the app from the Safari pwdDevelop menu.
* Set a breakpoint in `markup.js` from within the Safari Web Inspector. Note that `markup.js` in the Web Inspector is what you see in XCode in `MarkupEditor/Resources/markup.js`. This file was produced by rollup, and it contains packaged source from within `MarkupEditor/rollup/src/js`.
* Do whatever you need to in the app to cause it to hit the breakpoint. Step, step-in, etc to debug.
* Once you identify some JavaScript code to change, then go to VSCode opened on the `MarkupEditor/rollup` directory, and modify the original file in `src/js`. which will almost certainly be one of the key files identified above.
* Execute `npm run build` from the `MarkupEditor/rollup` directory in the terminal window of VSCode.
* Relaunch the app to check that the fix/change worked.
