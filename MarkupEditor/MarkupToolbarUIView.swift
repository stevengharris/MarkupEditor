//
//  UIMarkupToolbar.swift
//  UIKitDemo
//
//  Created by Steven Harris on 8/13/22.
//

import SwiftUI
import Combine

/// The UIMarkupToolbar is a UIView you can use in UIKit apps to include the SwiftUI MarkupToolbar.
///
/// The UIMarkupToolbar itself is included in the MarkupEditor library because it is used as the
/// `inputAccessoryView` in the MarkupWKWebView whether you are using SwiftUI or UIKit.
/// In this case, the MarkupWKWebView uses the `inputAccessory(in:markupDelegate:)`
/// here to get a properly-configured UIMarkupToolbar.  Note that a UIMarkupToolbar at the top of a
/// view would by default extend its subtoolbar to the bottom,  this is not the case for the
/// inputAccessoryView, since it sits at the top of the keyboard but has to show the SubToolbar
/// above.
///
/// The UIMarkupToolbar is used by the UIMarkupViewController, which is part of the UIKitDemo.
public class MarkupToolbarUIView: UIView {
    weak private var vc: UIViewController?
    private var markupDelegate: MarkupDelegate?
    private var showSubToolbarType: AnyCancellable?
    private var subToolbarHeightConstraint: NSLayoutConstraint!
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    public init(_ style: ToolbarStyle.Style? = nil, markupDelegate: MarkupDelegate? = nil, hideKeyboardButton: Bool = true, leftToolbar: AnyView? = nil, rightToolbar: AnyView? = nil, subToolbarEdge: Edge = .bottom) {
        super.init(frame: CGRect.zero)
        self.markupDelegate = markupDelegate
        let markupToolbar = MarkupToolbar(style, markupDelegate: markupDelegate, hideKeyboardButton: hideKeyboardButton, withSubToolbar: false)
        let markupToolbarHC = UIHostingController(rootView: markupToolbar)
        addSubview(markupToolbarHC.view)
        markupToolbarHC.view.translatesAutoresizingMaskIntoConstraints = false
        let subToolbar = SubToolbar(markupDelegate: markupDelegate)
        let subToolbarHC = UIHostingController(rootView: subToolbar)
        addSubview(subToolbarHC.view)
        subToolbarHC.view.translatesAutoresizingMaskIntoConstraints = false
        subToolbarHeightConstraint = NSLayoutConstraint(item: subToolbarHC.view!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: 0)
        if subToolbarEdge == .bottom {
            NSLayoutConstraint.activate([
                markupToolbarHC.view.topAnchor.constraint(equalTo: topAnchor),
                markupToolbarHC.view.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.height()),
                markupToolbarHC.view.leftAnchor.constraint(equalTo: leftAnchor),
                markupToolbarHC.view.rightAnchor.constraint(equalTo: rightAnchor),
                subToolbarHC.view.topAnchor.constraint(equalTo: markupToolbarHC.view.bottomAnchor),
                subToolbarHeightConstraint,
                subToolbarHC.view.leftAnchor.constraint(equalTo: leftAnchor),
                subToolbarHC.view.rightAnchor.constraint(equalTo: rightAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                markupToolbarHC.view.bottomAnchor.constraint(equalTo: bottomAnchor),
                markupToolbarHC.view.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.height()),
                markupToolbarHC.view.leftAnchor.constraint(equalTo: leftAnchor),
                markupToolbarHC.view.rightAnchor.constraint(equalTo: rightAnchor),
                subToolbarHC.view.bottomAnchor.constraint(equalTo: markupToolbarHC.view.topAnchor),
                subToolbarHeightConstraint,
                subToolbarHC.view.leftAnchor.constraint(equalTo: leftAnchor),
                subToolbarHC.view.rightAnchor.constraint(equalTo: rightAnchor),
            ])
        }
        observeShowSubToolbarType()
    }
    
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func observeShowSubToolbarType() {
        showSubToolbarType = MarkupEditor.showSubToolbar.$type.sink { [weak self] type in
            if type == .none {
                self?.subToolbarHeightConstraint.constant = 0
            } else {
                self?.subToolbarHeightConstraint.constant = MarkupEditor.toolbarStyle.height()
            }
        }
    }
    
    public static func inputAccessory(markupDelegate: MarkupDelegate? = nil) -> MarkupToolbarUIView {
        let toolbar = MarkupToolbarUIView(.compact, markupDelegate: markupDelegate, hideKeyboardButton: false, subToolbarEdge: .top)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.heightAnchor.constraint(equalToConstant: MarkupEditor.toolbarStyle.height()),
        ])
        return toolbar
    }
    
}
