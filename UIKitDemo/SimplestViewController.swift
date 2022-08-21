//
//  SimplestViewController.swift
//  UIKitDemo
//
//  Created by Steven Harris on 8/20/22.
//

import UIKit
import MarkupEditor

class SimplestViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let markupEditorUIView = MarkupEditorUIView(html: "<h1>Hello World</h1>")
        markupEditorUIView.frame = view.frame
        markupEditorUIView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(markupEditorUIView)
    }
    
}
