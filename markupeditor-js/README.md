# markupeditor-js

This directory contains an npm project with a single dependency - _markupeditor-base_. Its purpose is to make it easy to coordinate development between the Swift MarkupEditor and the JavaScript code it depends on, which is in [markupeditor-base](https://github.com/stevengharris/markupeditor-base). It will only be of interest to developers who need to work in the JavaScript code used by the Swift MarkupEditor. If you are a Swift developer who needs to debug into the JavaScript code, you can jump to the [discussion about that](#debugging).

## Background

The MarkupEditor has some reasonable built-in mechanisms for customization. These mechanisms are intended to help avoid forking the repository just to get the presentation or behavior you need within your Swift app. For example, you can modify the contents and presentation in the MarkupToolbar, and you can override the callbacks made to your MarkupDelegate to customize behavior. You can add your own CSS and control the styling of the MarkupWKWebView, and you can load your own JavaScript scripts into it that you can invoke from Swift. These mechanisms are documented in the [README](https://github.com/stevengharris/MarkupEditor/blob/main/README.md) in the expectation that many users will need them at some point.

Some users will want to dig deeper or will need to change the JavaScript code that is modifying the document in the MarkupWKWebView as you edit. In earlier versions of the MarkupEditor, the answer was basically: fork the project and edit `Resources/markup.js`. The answer is no longer that simple because `Resources/markup.js` is now an artifact produced by building the [markupeditor-base](https://github.com/stevengharris/markupeditor-base) project. That project in turn uses the excellent [ProseMirror](https://prosemirror.net) for the heavy lifting of WYSIWYG editing behind the scenes.

## Learn More About markupeditor-base

The [project web site](https://stevengharris.github.io/markupeditor-base/) is a good starting point. The [markupeditor-base repository](https://github.com/stevengharris/markupeditor-base) comes with documentation on how to install and build. You should also be familiar with [Developer's Guide](https://stevengharris.github.io/markupeditor-base/guide/index.html), which explains the concepts behind markupeditor-base as well as how the Swift code interacts with the JavaScript code and vice-versa. To do any significant debugging or development, you will also need to understand some about [ProseMirror](https://prosemirror.net/docs/guide/) concepts.

Just like the Swift MarkupEditor has demos built in SwiftUI and UIKit, markupeditor-base has a [demo](https://stevengharris.github.io/markupeditor-base/demo/index.html) built in JavaScript. In the Swift MarkupEditor, you need to build a Swift demo app and deploy it to a device. In markupeditor-base, the demo just runs right in your browser or using node.js. The Swift MarkupEditor uses a SwiftUI-based MarkupToolbar, whereas the markupeditor-base project uses a pure JavaScript/HTML/CSS-based toolbar.

The formalization of [markupeditor-base](https://github.com/stevengharris/markupeditor-base) allows the base code to be re-used beyond Swift applications. For example, there is a [MarkupEditor desktop application](https://github.com/stevengharris/markupeditor-desktop) built with it, as well as a [VSCode extension](https://github.com/stevengharris/markupeditor-vs). The contents of the [web site](https://stevengharris.github.io/markupeditor-base/) was all edited using the MarkupEditor desktop application.

## Working with the Swift MarkupEditor and markupeditor-base

Working with the markupeditor-base JavaScript code requires you to have node.js/npm installed. You can of course use whatever development tools you're comfortable with. I use VSCode for the markupeditor-base development and Xcode for Swift development.

There isn't any way to express directly in the MarkupEditor's `package.swift` file that it depends on markupeditor-base. However, the runtime dependency only involves the following files in the `MarkupEditor/Resources` directory:

* markup.js - A copy of `dist/markupeditor.umd.js` that was built using markupeditor-base.
* markup.css - Styling needed to support basic MarkupEditor editing.
* mirror.css - Styling needed to support basic ProseMirror editing.

These files are present in the Swift MarkupEditor's `Resources` directory and are part of the Swift MarkupEditor's source control. This way, you don't need to build markupeditor-base to install and build the Swift MarkupEditor as outlined in its [README](https://github.com/stevengharris/MarkupEditor).

The `markupeditor-js` directory defines an npm package in `package.json` that depends on markupeditor-base. By default, the markupeditor-base dependency is on the npm package in the npm registry. If you are going to be modifying the markupeditor-base code, you should clone the project and use a local dependency. Then you can work in a local markupeditor-base directory, build and test there, and your changes will be available within the Swift MarkupEditor project with a single `npm run prepare` command in markupeditor-js.

### Install the markupeditor-js Project

Install markupeditor-js, which also runs the prepare script that copies the runtime and test data dependencies from markupeditor-base into their expected locations in the Swift MarkupEditor.

```
$ npm install

> markupeditor@0.8.6 prepare
> sh prepare.sh

Updating dependencies from markupeditor-base...
 Copying ./node_modules/markupeditor-base/dist/markupeditor.umd.js
  to ../MarkupEditor/Resources/markup.js
 Copying ./node_modules/markupeditor-base/styles/markup.css
  to ../MarkupEditor/Resources/markup.css
 Copying ./node_modules/markupeditor-base/styles/mirror.css
  to ../MarkupEditor/Resources/mirror.css
 Copying ./node_modules/markupeditor-base/test/*.json
  to ../MarkupEditorTests/BaseTests/

added 19 packages, and audited 20 packages in 887ms

found 0 vulnerabilities
$
```

The `npm install` step populates `node_modules`. The `prepare` script makes sure the required files are present in `node_modules` and then copies them into the `MarkupEditor/Resources` directory.

### Using a Local markupeditor-base Dependency

Clone the project:

```
git clone https://github.com/stevengharris/markupeditor-base.git
```

Replace the default registry dev-dependency:

```
npm install <path to your cloned markupeditor-base> --save-dev
```

### Workflow

Do your work in markupeditor-base locally. Build in your markupeditor-base directory:

``` 
$ npm run build

> markupeditor-base@0.8.6 build
> rollup -c


src/main.js → dist/markupeditor.umd.js...
created dist/markupeditor.umd.js in 352ms

src/main.js → dist/markupeditor.cjs.js, dist/markupeditor.esm.js...
created dist/markupeditor.cjs.js, dist/markupeditor.esm.js in 72ms
$
```

Note that `npm run test` in the markupeditor-base directory will run all tests using JEST.

Now, _in the markupeditor-js directory of your cloned Swift MarkupEditor project_, run `prepare` to put the changes you made in markupeditor-base into the source control of the Swift MarkupEditor:

```
$ npm run prepare

> markupeditor@0.8.6 prepare
> sh prepare.sh

Updating dependencies from markupeditor-base...
 Copying ./node_modules/markupeditor-base/dist/markupeditor.umd.js
  to ../MarkupEditor/Resources/markup.js
 Copying ./node_modules/markupeditor-base/styles/markup.css
  to ../MarkupEditor/Resources/markup.css
 Copying ./node_modules/markupeditor-base/styles/mirror.css
  to ../MarkupEditor/Resources/mirror.css
 Copying ./node_modules/markupeditor-base/test/*.json
  to ../MarkupEditorTests/BaseTests/
$
```

The `prepare` script also copies the current test files from markupeditor-base into the proper place for the Swift project to find them. The Swift MarkupEditor uses the same test data (the .json files copied in `prepare`), but uses Swift Testing to execute them. In Xcode, the tests are run in the `BaseTests` target. The Swift BaseTests use the MarkupWKWebView API from within Swift, which in turn calls into the JavaScript web view using `evaluateJavaScript`. In general, the test data identifies `startHtml` along with the `endHtml` that is produced by applying an action of some kind. While the test data is shared between the Swift MarkupEditor and markupeditor-base, there may be additional processing in the MarkupWKWebView before and after executing `evaluateJavaScript`, so it's important to test independently in Swift and not just rely on the markupeditor-base testing.

To test your changes, you can run one of the Swift MarkupEditor demos, the tests, or whatever is appropriate. You probably have a separate project that has a dependency on the MarkupEditor. When you build it, the changes will be in effect.

## Debugging

I use the [Safari Web Inspector](https://developer.apple.com/documentation/safari-developer-tools/web-inspector) for debugging JavaScript code. Swift developers may not even be aware of its capabilities. If you have not enabled it before, in Safari -> Settings -> Advanced, check the "Show features for web developers" checkbox. This should add a Develop menu in Safari, which displays among other items a list of devices displaying web views that can be inspected. (You'll see Xcode there if you have the help section opened on the right, since that is an embedded web view!) When you're running an application displaying a MarkupWKWebView, like SwiftUIDemo on your Mac or iPhone or in the simulator, the app will show up in the Develop menu under the device it is running on. Select the app, and the Safari Web Inspector will open. You can see what scripts are loaded, set breakpoints, see the DOM, and check out how CSS styling is working among many other things. 

Note that the MarkupEditor sets `isInspectable` to `true` for the MarkupWKWebView in DEBUG builds. This has been necessary to use the Safari Web Inspector since iOS 16.4. The default is `false`, so you (and your users) won't be able to inspect non-DEBUG builds or your production app.

A debugging cycle often consists of:

* Launch the app.
* Open the Safari Web Inspector on the app from the Safari Develop menu.
* Set a breakpoint in `markup.js` from within the Safari Web Inspector. Note that `markup.js` in the Web Inspector is what you see in XCode in `MarkupEditor/Resources/markup.js`.
* Do whatever you need to in the app to cause it to hit the breakpoint. Step, step-in, etc to debug.
* Once you identify some JavaScript code to change, you need to make changes to the file it was created-in in the markupeditor-base project. The `markup.js` file you're debugging was produced by [rollup](https://rollupjs.org) within the markupeditor-base project. The _MarkupEditor Project Structure_ section of the [Developer's Guide](https://stevengharris.github.io/markupeditor-base/guide/index.html) offers some information, or just use your development tools to identify the original source file that was rolled-up into `markupeditor.umd.js` and then copied to `Resources/markup.js` in the Swift MarkupEditor project.
* Execute `npm run build` from the markupeditor-base project directory in the terminal window to rebuild `markupeditor.umd.js`.
* Execute `npm run prepare` from the `markupeditor-js` directory of the Swift MarkupEditor project to copy the markupeditor-base files to their proper location in the Swift MarkupEditor project structure.
* Relaunch the app to check that the fix/change worked.

Note that if you are just making CSS changes, you don't need to rebuild, and `npm run prepare` will copy those changes to the `MarkupEditor/Resources` directory.

It can be helpful to do as much debugging as possible directly in markupeditor-base. The [demo](https://stevengharris.github.io/markupeditor-base/demo/index.html) often provides a straightforward way to test your changes and avoid a Swift app rebuild. If you are encountering a MarkupEditor bug and can reproduce it in markupeditor-base, it makes it easier to address any issues you file.
