# UIKit Dependency Audit - Task 1.2

**Date**: 2026-01-20
**Branch**: macosphase1
**Status**: Complete

---

## Executive Summary

Audit of MarkupEditor codebase identified UIKit dependencies in **4 key files** requiring platform-specific conditioning for macOS support:

| File | UIKit Usage Count | Risk Level | Impact |
|------|-----------------|------------|--------|
| MarkupWKWebView.swift | 23 instances | High | Core pasteboard, keyboard, responder chain |
| MarkupDelegate.swift | 8 instances | Medium | Drop interaction, UIApplication, protocol parameters |
| SelectionState.swift | Imports only (no usage) | Low | Remove redundant import |
| StyleContext.swift | Imports only (no usage) | Low | Remove redundant import |

**Total Files Requiring Modification**: 4 (2 with actual changes, 2 with import cleanup)
**Total UIKit-Only Files to Exclude**: 8 files (Toolbars folder + UIView-only files)

---

## Detailed Findings

### 1. MarkupWKWebView.swift (23 UIKit instances)

**File Path**: `MarkupEditor/MarkupWKWebView.swift`
**Lines**: ~1879
**Risk**: High

**UIKit Dependencies Found**:

#### A. UIView and Keyboard Handling (lines 80-98)
```swift
public var accessoryView: UIView? {
    didSet {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidHide), name: UIResponder.keyboardDidHideNotification, object: nil)
    }
}
```
**Issue**: UIView type, UIResponder keyboard notifications
**macOS Impact**: macOS has no UIView, different keyboard handling
**Solution**: Wrap in `#if canImport(UIKit)` / `#else` with AppKit alternative

#### B. Toolbar Accessory View (line 164)
```swift
inputAccessoryView = MarkupToolbarUIView.inputAccessory(markupDelegate: markupDelegate)
```
**Issue**: inputAccessoryView is UIResponder API
**macOS Impact**: Not available on macOS; use HTML toolbar instead
**Solution**: Wrap in `#if os(iOS)` conditional

#### C. Hit Test Override (line 583)
```swift
open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView?
```
**Issue**: UIEvent, UIView return type
**macOS Impact**: Different event handling on macOS (NSEvent)
**Solution**: Wrap in `#if canImport(UIKit)` and create AppKit alternative

#### D. Responder Standard Edit Actions (lines 623, 625, 627)
```swift
case #selector(UIResponderStandardEditActions.select(_:)), #selector(UIResponderStandardEditActions.selectAll(_:)):
case #selector(UIResponderStandardEditActions.copy(_:)), #selector(UIResponderStandardEditActions.cut(_:)):
case #selector(UIResponderStandardEditActions.paste(_:)), #selector(UIResponderStandardEditActions.pasteAndMatchStyle(_:)):
```
**Issue**: UIResponderStandardEditActions (UIKit only)
**macOS Impact**: Different responder chain handling
**Solution**: Wrap in `#if canImport(UIKit)` / `#else` for macOS equivalents

#### E. Keyboard Frame Extraction (line 528)
```swift
let keyboardFrameEnd = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
```
**Issue**: UIResponder keyboard info key
**macOS Impact**: macOS keyboards handled differently
**Solution**: Wrap keyboard notification handlers in `#if os(iOS)`

#### F. UIPasteboard Operations (4 locations: lines 982, 1262, 1741, 1833)
```swift
// Line 982:
let pasteboard = UIPasteboard.general

// Line 1262:
let pasteboard = UIPasteboard.general

// Line 1741:
let pasteboard = UIPasteboard.general

// Line 1833:
let pasteboard = UIPasteboard.general
```
**Issue**: UIPasteboard (iOS only), NSPasteboard on macOS
**macOS Impact**: Critical - pasteboard operations won't compile
**Solution**: `#if canImport(UIKit)` for UIPasteboard, `#else` for NSPasteboard with equivalent API

#### G. UIImage Paste Methods (lines 1309, 1336)
```swift
public func pasteImage(_ image: UIImage?, handler: (()->Void)? = nil) {
    // ...
}

public func pasteImage(_ image: UIImage?) async {
    // ...
}
```
**Issue**: UIImage parameter type
**macOS Impact**: Use NSImage on macOS
**Solution**: Create platform type alias (PlatformImage = UIImage on iOS, NSImage on macOS)

#### H. inputAccessoryView Property Override (line 612)
```swift
public override var inputAccessoryView: UIView? {
    // Implementation
}
```
**Issue**: UIResponder API (inputAccessoryView)
**macOS Impact**: Not available on macOS
**Solution**: Wrap implementation in `#if canImport(UIKit)`

---

### 2. MarkupDelegate.swift (8 UIKit instances)

**File Path**: `MarkupEditor/MarkupDelegate.swift`
**Lines**: ~356
**Risk**: Medium

**UIKit Dependencies Found**:

#### A. Drop Interaction Protocol Methods (lines 110, 113, 116)
```swift
func markupDropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool
func markupDropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal
func markupDropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession)
```
**Issue**: UIDropInteraction, UIDropSession, UIDropProposal (UIKit only)
**macOS Impact**: Drop handling on macOS uses different APIs
**Solution**: Wrap protocol methods in `#if canImport(UIKit)` / `#else`

#### B. UIApplication URL Handling (lines 207-208)
```swift
public func markupLinkSelected(_ view: MarkupWKWebView?, selectionState: SelectionState) {
    guard let href = selectionState.href,
          let url = URL(string: href),
          UIApplication.shared.canOpenURL(url) else { return }
    UIApplication.shared.open(url)
}
```
**Issue**: UIApplication.shared (UIKit only)
**macOS Impact**: Use NSWorkspace.shared on macOS
**Solution**: `#if canImport(UIKit)` for UIApplication, `#else` for NSWorkspace

#### C. Default Drop Proposal (lines 285, 291-292, 296)
```swift
public func markupDropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
    false
}

public func markupDropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
    UIDropProposal(operation: .copy)
}

public func markupDropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {}
```
**Issue**: Same UIKit drop interaction types
**macOS Impact**: Default implementations need macOS alternatives
**Solution**: Conditionally compile all drop-related implementations

**Note**: MarkupDelegate imports UIKit but actually only needs it for the drop interaction types. The import statement at line 9 should remain but methods should be conditionally compiled.

---

### 3. SelectionState.swift (Import Only)

**File Path**: `MarkupEditor/Selection/SelectionState.swift`
**Issue**: Imports UIKit but only uses CGRect/CGSize
**Analysis**: CGRect/CGSize are from CoreGraphics, not UIKit
**Solution**: Replace `import UIKit` with `import CoreGraphics`

**Code Reference**:
```swift
// Line 19:
@Published public var selrect: CGRect? = nil

// Line 60:
return CGRect(origin: selrect.origin, size: CGSize(width: max(selrect.width, 1), height: max(selrect.height, 1)))
```

---

### 4. StyleContext.swift (Import Only)

**File Path**: `MarkupEditor/Selection/StyleContext.swift`
**Issue**: Imports UIKit but doesn't use it
**Analysis**: Pure enum with no UIKit dependencies
**Solution**: Remove `import UIKit` statement

---

### 5. UIView+Extensions.swift (Platform-Specific)

**File Path**: `MarkupEditor/Extensions/UIView+Extensions.swift`
**Issue**: UIView-only extension
**macOS Impact**: UIView doesn't exist on macOS
**Solution**: **EXCLUDE from macOS target** (don't compile on macOS)

---

## Files to Exclude from macOS Target

| Folder/File | Reason | Count |
|------------|--------|-------|
| MarkupEditor/Toolbars/ (entire folder) | SwiftUI toolbars - iOS/MacCatalyst only | 8 files |
| MarkupEditor/MarkupEditorUIView.swift | UIView-based view | 1 file |
| MarkupEditor/Extensions/UIView+Extensions.swift | UIView extensions | 1 file |
| MarkupEditor/Utilities/PopoverHostingController.swift | UIViewController-based | 1 file |
| MarkupEditor/Utilities/ImageViewController.swift | UIViewController-based | 1 file |
| MarkupEditor/Utilities/LinkViewController.swift | UIViewController-based | 1 file |

**Total Files to Exclude**: 13 files

---

## Files to Keep (Platform-Agnostic)

| Folder | Status | Note |
|--------|--------|------|
| MarkupEditor/Divs/ | Include on macOS | Foundation + OSLog only |
| MarkupEditor/Selection/ (requires import fix) | Include on macOS | CGRect is from CoreGraphics |
| MarkupEditor/Utilities/ (partial) | Most included | Only exclude specific files above |

---

## Conditional Compilation Strategy

### Pattern 1: Broad Platform Separation
Used for major sections like pasteboard handling:
```swift
#if canImport(UIKit)
import UIKit
// iOS/MacCatalyst code
#else
import AppKit
// macOS code
#endif
```

### Pattern 2: Fine-Grained Platform Handling
Used for specific method implementations like keyboard notifications:
```swift
#if os(iOS)
// iOS-only code
#else
// macOS code or empty/different implementation
#endif
```

### Pattern 3: Type Aliases
For cross-platform type compatibility:
```swift
#if canImport(UIKit)
typealias PlatformImage = UIImage
#else
typealias PlatformImage = NSImage
#endif
```

---

## Implementation Priority

### Priority 1: Critical (Must Fix for Compilation)
1. **UIPasteboard** (4 locations in MarkupWKWebView.swift)
   - Lines 982, 1262, 1741, 1833
   - Impact: Pasteboard operations won't compile without fix
   - Replacement: NSPasteboard on macOS

2. **UIImage Type** (2 pasteImage methods)
   - Lines 1309, 1336
   - Impact: Type mismatch
   - Solution: Platform type alias

### Priority 2: Important (Break Compilation on macOS)
1. **UIResponder Keyboard Notifications** (lines 86-94, 528)
   - Impact: Keyboard handling won't work
   - Solution: Wrap in `#if os(iOS)` or `#if canImport(UIKit)`

2. **UIDropInteraction** (MarkupDelegate protocol)
   - Impact: Drop handling won't compile
   - Solution: Conditional protocol methods

### Priority 3: Cleanup (Import Fixes)
1. **SelectionState.swift** - Replace UIKit import with CoreGraphics
2. **StyleContext.swift** - Remove unused UIKit import

---

## Summary by Modification Type

| Modification Type | File Count | Files |
|-------------------|-----------|-------|
| Require Conditional Compilation | 2 | MarkupWKWebView.swift, MarkupDelegate.swift |
| Import Fixes (Simple) | 2 | SelectionState.swift, StyleContext.swift |
| Exclude from macOS | 13 | Toolbars folder + UIView-only files |
| No Changes Required | 30+ | Remaining files |

---

## Next Steps (Task 1.3)

Create platform abstraction layer with:
1. Type aliases for cross-platform compatibility (PlatformImage, PasteboardHelper)
2. Conditional imports at file level
3. Implementation stubs for macOS equivalents where needed

---

## Verification Checklist

- [x] MarkupWKWebView.swift audited - 23 UIKit instances found
- [x] MarkupDelegate.swift audited - 8 UIKit instances found
- [x] Selection/ folder audited - Import fixes needed
- [x] Extensions/ folder audited - UIView+Extensions to exclude
- [x] All UIKit dependencies documented
- [x] Exclusion list identified (13 files)
- [x] Conditional compilation patterns identified
- [x] Implementation priority established

**Audit Status**: ✅ Complete
