//
//  MarkupToolbarUIView.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/13/22.
//

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
/// Note that a MarkupToolbarUIView at the top of a view would by default extend its subtoolbar to the bottom,
/// this is not the case for the inputAccessoryView, since it sits at the top of the keyboard but has to show the
/// SubToolbar above. By default, no SubToolbar is used. If you want to override the default behavior, though,
/// and set MarkupEditor.toolbarPosition = .none and use the entire MarkupToolbar in as the inputAccessoryView,
/// then it will work properly and expose the SubToolbar as part of the inputAccessoryView as needed.
///
public class MarkupToolbarUIView: UIView {
    public var markupToolbar: MarkupToolbar!
    private var markupDelegate: MarkupDelegate?
    public var showSubToolbar: ShowSubToolbar { markupToolbar.showSubToolbar }
    public var showSubToolbarCancellable: AnyCancellable?
    private var subToolbarHeightConstraint: NSLayoutConstraint!
    
    /// The intrinsicContentSize depends on the MarkupEditor.showSubToolbar.type so that there will be enough
    /// height to show the SubToolbar.
    public override var intrinsicContentSize: CGSize {
        if markupToolbar.showSubToolbar.type == .none {
            return CGSize(width: frame.width, height: MarkupEditor.toolbarStyle.height()) }
        else {
            return CGSize(width: frame.width, height: 2.0 * MarkupEditor.toolbarStyle.height())
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    public init(_ style: ToolbarStyle.Style? = nil, contents: ToolbarContents? = nil, markupDelegate: MarkupDelegate? = nil, withKeyboardButton: Bool = false, subToolbarEdge: Edge = .bottom) {
        super.init(frame: CGRect.zero)
        self.markupDelegate = markupDelegate
        autoresizingMask = .flexibleHeight  // Needed for the intrinsicContentSize change to work
        markupToolbar = MarkupToolbar(style, contents: contents, markupDelegate: markupDelegate, withKeyboardButton: withKeyboardButton, withSubToolbar: false)
        let markupToolbarHC = UIHostingController(rootView: markupToolbar)
        addSubview(markupToolbarHC.view)
        markupToolbarHC.view.translatesAutoresizingMaskIntoConstraints = false
        let subToolbar = SubToolbar(for: markupToolbar)
        let subToolbarHC = UIHostingController(rootView: subToolbar)
        addSubview(subToolbarHC.view)
        subToolbarHC.view.translatesAutoresizingMaskIntoConstraints = false
        subToolbarHeightConstraint = NSLayoutConstraint(item: subToolbarHC.view!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: 0)
        if subToolbarEdge == .bottom {
            NSLayoutConstraint.activate([
                markupToolbarHC.view.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
                markupToolbarHC.view.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.height()),
                markupToolbarHC.view.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
                markupToolbarHC.view.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor),
                subToolbarHC.view.topAnchor.constraint(equalTo: markupToolbarHC.view.bottomAnchor),
                subToolbarHeightConstraint,
                subToolbarHC.view.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
                subToolbarHC.view.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                markupToolbarHC.view.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
                markupToolbarHC.view.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.height()),
                markupToolbarHC.view.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
                markupToolbarHC.view.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor),
                subToolbarHC.view.bottomAnchor.constraint(equalTo: markupToolbarHC.view.topAnchor),
                subToolbarHeightConstraint,
                subToolbarHC.view.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor),
                subToolbarHC.view.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor),
            ])
        }
        observeShowSubToolbarType()
    }
    
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func observeShowSubToolbarType() {
        showSubToolbarCancellable = markupToolbar.showSubToolbar.$type.sink { [weak self] type in
            guard let self = self, let subToolbarHeightConstraint = self.subToolbarHeightConstraint else { return }
            if type == .none {
                subToolbarHeightConstraint.constant = 0
            } else {
                subToolbarHeightConstraint.constant = MarkupEditor.toolbarStyle.height()
            }
            self.invalidateIntrinsicContentSize()
        }
    }
    
    public func makeManaged() -> MarkupToolbarUIView {
        markupToolbar = markupToolbar.makeManaged()
        return self
    }
    
    /// Return a MarkupToolbarUIView that is compact, containing the current shared ToolbarContents, but makes sure keyboardButton is present.
    public static func inputAccessory(markupDelegate: MarkupDelegate? = nil) -> MarkupToolbarUIView {
        let contents = ToolbarContents.from(ToolbarContents.shared)
        return MarkupToolbarUIView(.compact, contents: contents, markupDelegate: markupDelegate, withKeyboardButton: true, subToolbarEdge: .top).makeManaged()
    }
    
}
