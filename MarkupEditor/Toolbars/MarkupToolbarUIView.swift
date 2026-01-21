//
//  MarkupToolbarUIView.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/13/22.
//


#if !os(macOS)

import SwiftUI
import Combine

/// The MarkupToolbarUIView is a UIView you can use in UIKit apps to include the SwiftUI MarkupToolbar.
///
/// MarkupEditorUIView combines the MarkupToolbarUIView with the MarkupWKWebView in a single UIView,
/// so it's easier to present them together. You can use them two views independently yourself if needed.
/// For example, you would want to do that if you have more than one MarkupWKWebView that share a
/// single MarkupToolbarUIView.
///
/// If you are building a "pure" SwiftUI app, you still need the MarkupToolbarUIView, because it is needed
/// if you are going to use the MarkupToolbar in the MarkupWKWebView's inputAccessoryView.
///
/// By default, the MarkupToolbarUIView is used as the inputAccessoryView in the MarkupWKWebView
/// whether you are using SwiftUI or UIKit. In this case, the MarkupWKWebView uses the static method
/// `inputAccessory(markupDelegate:)` here to get a properly-configured MarkupToolbarUIView.
/// The default configuration for the inputAccessory version of the MarkupToolbarUIView is to include *only*
/// the CorrectionToolbar and an ability to hide the keyboard. This is because the default MarkupToolbar does
/// not include the undo/redo buttons (i.e., the CorrectionToolbar), and in MacCatalyst or on a device with a
/// physical keyboard, the undo/redo are available from the menu and has hotkeys, but not on a device without
/// a physical keyboard.
///
public class MarkupToolbarUIView: UIView {
    public var markupToolbar: MarkupToolbar!
    private var markupDelegate: MarkupDelegate?
    
    public override var intrinsicContentSize: CGSize {
        CGSize(width: frame.width, height: MarkupEditor.toolbarStyle.height())
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    public init(_ style: ToolbarStyle.Style? = nil, contents: ToolbarContents? = nil, markupDelegate: MarkupDelegate? = nil, withKeyboardButton: Bool = false) {
        super.init(frame: CGRect.zero)
        self.markupDelegate = markupDelegate
        autoresizingMask = .flexibleHeight  // Needed for the intrinsicContentSize change to work
        markupToolbar = MarkupToolbar(style, contents: contents, markupDelegate: markupDelegate, withKeyboardButton: withKeyboardButton)
        let markupToolbarHC = UIHostingController(rootView: markupToolbar)
        addSubview(markupToolbarHC.view)
        markupToolbarHC.view.translatesAutoresizingMaskIntoConstraints = false
        if MarkupEditor.toolbarLocation == .top || MarkupEditor.toolbarLocation == .keyboard {
            NSLayoutConstraint.activate([
                markupToolbarHC.view.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                markupToolbarHC.view.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.height()),
                markupToolbarHC.view.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
                markupToolbarHC.view.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                markupToolbarHC.view.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
                markupToolbarHC.view.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.height()),
                markupToolbarHC.view.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
                markupToolbarHC.view.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor),
            ])
        }
    }
    
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func makeManaged() -> MarkupToolbarUIView {
        markupToolbar = markupToolbar.makeManaged()
        return self
    }
    
    /// Return a MarkupToolbarUIView that is compact, containing the current shared ToolbarContents, but makes sure keyboardButton is present.
    public static func inputAccessory(markupDelegate: MarkupDelegate? = nil) -> MarkupToolbarUIView {
        let contents = ToolbarContents.from(ToolbarContents.shared)
        let toolbar = MarkupToolbarUIView(.compact, contents: contents, markupDelegate: markupDelegate, withKeyboardButton: true).makeManaged()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return toolbar
    }
    
}


#endif
