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

struct SubToolbar_Previews: PreviewProvider {
    // This is just a container for a specific SubToolbar dynamically specified by type
    static var previews: some View {
        let compactMarkupEnv = MarkupEnv(style: .compact)
        let compactPreference = compactMarkupEnv.toolbarPreference
        let labeledMarkupEnv = MarkupEnv(style: .labeled)
        let labeledPreference = labeledMarkupEnv.toolbarPreference
        let showSubToolbar = ShowSubToolbar()
        VStack(alignment: .leading) {
            HStack {
                SubToolbar(markupDelegate: nil)
                    .environmentObject(SelectionState())
                    .environmentObject(compactPreference)
                    .environmentObject(showSubToolbar)
                    .frame(height: compactPreference.height())
                Spacer()
            }
            HStack {
                SubToolbar(markupDelegate: nil)
                    .environmentObject(SelectionState())
                    .environmentObject(labeledPreference)
                    .environmentObject(showSubToolbar)
                    .frame(height: labeledPreference.height())
                Spacer()
            }
            Spacer()
        }
    }
}
