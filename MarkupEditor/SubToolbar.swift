//
//  SubToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 6/27/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The sub-toolbar used for creating/editing links, images, and tables.
public struct SubToolbar: View {
    
    public enum ToolbarType {
        case image
        case link
        case table
    }
    
    @EnvironmentObject var showSubToolbar: ShowSubToolbar
    @EnvironmentObject private var observedWebView: ObservedWebView
    @EnvironmentObject private var selectionState: SelectionState
    private var markupDelegate: MarkupDelegate?
    
    public var body: some View {
        VStack(spacing: 0) {
            if showSubToolbar.type == .link {
                LinkToolbar(selectionState: selectionState)
                    .onAppear {
                        markupDelegate?.markupToolbarAppeared(type: .link)
                    }
                    .onDisappear {
                        markupDelegate?.markupToolbarDisappeared()
                        observedWebView.selectedWebView?.becomeFirstResponder()
                    }
            }
            if showSubToolbar.type == .image {
                ImageToolbar(selectionState: selectionState)
                    .onAppear {
                        markupDelegate?.markupToolbarAppeared(type: .image)
                    }
                    .onDisappear {
                        markupDelegate?.markupToolbarDisappeared()
                        observedWebView.selectedWebView?.becomeFirstResponder()
                    }
            }
            if showSubToolbar.type == .table {
                TableToolbar()
                    .onAppear {
                        markupDelegate?.markupToolbarAppeared(type: .table)
                    }
                    .onDisappear {
                        markupDelegate?.markupToolbarDisappeared()
                        observedWebView.selectedWebView?.becomeFirstResponder()
                    }
            }
            Divider()
        }
        
    }
    
    public init(markupDelegate: MarkupDelegate?) {
        self.markupDelegate = markupDelegate
    }
    
}
