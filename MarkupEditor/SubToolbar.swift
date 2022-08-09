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

    @State private var toolbarStyle: ToolbarStyle
    @ObservedObject private var showSubToolbar: ShowSubToolbar = MarkupEditor.showSubToolbar
    @ObservedObject private var observedWebView: ObservedWebView = MarkupEditor.observedWebView
    @ObservedObject private var selectionState: SelectionState = MarkupEditor.selectionState
    private var markupDelegate: MarkupDelegate?
    
    public var body: some View {
        VStack(spacing: 0) {
            if showSubToolbar.type == .link {
                LinkToolbar()
                    .onAppear {
                        markupDelegate?.markupToolbarAppeared(type: .link)
                    }
                    .onDisappear {
                        markupDelegate?.markupToolbarDisappeared()
                        observedWebView.selectedWebView?.becomeFirstResponder()
                    }
            }
            if showSubToolbar.type == .image {
                ImageToolbar()
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
        .environmentObject(toolbarStyle)
        
    }
    
    public init(_ style: ToolbarStyle.Style? = nil, markupDelegate: MarkupDelegate? = nil) {
        let toolbarStyle = style == nil ? MarkupEditor.toolbarStyle : ToolbarStyle(style!)
        _toolbarStyle = State(initialValue: toolbarStyle)
        self.markupDelegate = markupDelegate
    }
    
}

struct SubToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading) {
            SubToolbar(.compact)
            SubToolbar(.labeled)
            Spacer()
        }
        .onAppear { MarkupEditor.showSubToolbar.type = .table }
    }
}
