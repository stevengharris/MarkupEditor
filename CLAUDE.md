# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MarkupEditor is a WYSIWYG rich text editor framework for iOS and macCatalyst applications. It wraps the ProseMirror JavaScript library in a WKWebView and provides SwiftUI/UIKit components for embedding rich text editing in apps.

## Architecture

**Swift/WebView Bridge Pattern:**
- `MarkupWKWebView` - Core WKWebView subclass handling Swift↔JavaScript communication via `evaluateJavaScript`
- `MarkupCoordinator` - WKScriptMessageHandler receiving JavaScript callbacks in `userContentController(_:didReceive:)`
- `MarkupDelegate` - Protocol for apps to receive change notifications

**UI Layer:**
- `MarkupEditorView` (SwiftUI) / `MarkupEditorUIView` (UIKit) - Main editor views
- `MarkupToolbar` / `MarkupToolbarUIView` - Configurable toolbar with sub-toolbars (Style, Format, Insert, Correction, Table)
- `MarkupEditor` struct holds global state (`selectedWebView`, `selectionState`)

**JavaScript Layer (in `MarkupEditor/Resources/`):**
- `markup.js` - Built artifact from markupeditor-base (ProseMirror wrapper)
- `markup.css`, `mirror.css` - Styling for editor and ProseMirror

## Build Commands

**Swift Package:**
```bash
swift build
```

**Run Tests (Xcode):**
- `BaseTests` target - Parameterized tests from JSON files, covers toolbar actions with undo/redo
- `SwiftTests` target - Swift-specific functionality (e.g., image pasting)

Tests use Swift Testing framework with `@Suite(.serialized)` for WKWebView initialization.

## JavaScript Development

The `markupeditor-js/` directory coordinates JavaScript development with markupeditor-base:

```bash
cd markupeditor-js
npm install              # Install deps and run prepare script
npm run prepare          # Copy JS/CSS files to MarkupEditor/Resources/
```

The prepare script copies:
- `markupeditor.umd.js` → `MarkupEditor/Resources/markup.js`
- CSS files → `MarkupEditor/Resources/`
- Test JSON files → `MarkupEditorTests/BaseTests/`

**Local markupeditor-base development:**
```bash
npm install <path-to-local-markupeditor-base> --save-dev
# Make changes in markupeditor-base, then:
cd markupeditor-base && npm run build
cd ../markupeditor-js && npm run prepare
```

## Debugging JavaScript

Use Safari Web Inspector (Safari → Develop menu → select running app). Set breakpoints in `markup.js`. The MarkupEditor sets `isInspectable = true` in DEBUG builds.

## Key Files

- `MarkupEditor/MarkupWKWebView.swift` - Core editing API, JavaScript interop
- `MarkupEditor/MarkupCoordinator.swift` - JavaScript callback handling
- `MarkupEditor/MarkupDelegate.swift` - App-facing protocol with callbacks
- `MarkupEditor/SelectionState.swift` - Tracks current selection and formatting state
- `MarkupEditor/Resources/markup.html` - Base HTML document with `<markup-editor>` web component

## Test Structure

Tests use JSON files from markupeditor-base defining `startHtml`, `endHtml`, and actions. Each test validates:
1. Action produces expected HTML
2. Undo restores original state
3. Redo reapplies the action
4. Selection is correct after each operation
