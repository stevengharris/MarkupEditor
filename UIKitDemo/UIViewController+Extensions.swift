//
//  UIViewController+Extensions.swift
//  UIKitDemo
//
//  Created by Steven Harris on 3/9/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import UIKit
import SwiftUI

extension UIViewController {

    /// Add a SwiftUI `View` as a child of the input `UIView`.
    /// - Parameters:
    ///   - swiftUIView: The SwiftUI `View` to add as a child.
    ///   - view: The `UIView` instance to which the view should be added.
    func add<Content>(swiftUIView: Content, to view: UIView) where Content : View {
        let hostingController = UIHostingController(rootView: swiftUIView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
    
    /// Overlay a SwiftUI `View` as a child of the input `UIView` at the top, across the full `UIView`.
    /// - Parameters:
    ///   - swiftUIView: The SwiftUI `View` to add as a child.
    ///   - view: The `UIView` instance on which the view should be overlayed at the top.
    /// - Returns: The UIView that is created inside of a UIHostingController, which may be useful, for example, to hide the view.
    @discardableResult func overlayTop<Content>(swiftUIView: Content, on view: UIView, height: CGFloat) -> UIView where Content : View {
        let hostingController = UIHostingController(rootView: swiftUIView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.heightAnchor.constraint(equalToConstant: height),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leftAnchor.constraint(equalTo: view.leftAnchor),
            hostingController.view.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
        hostingController.didMove(toParent: self)
        return hostingController.view
    }
    
}
