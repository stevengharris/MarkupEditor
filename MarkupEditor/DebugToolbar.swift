//
//  DebugToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//

import SwiftUI

struct DebugToolbar: View {
    
    typealias DisplayFormat = MarkupWKWebView.DisplayFormat
    
    
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    @Binding private var selectedFormat: DisplayFormat
    
    var body: some View {
        HStack {
            Divider()
            VStack(spacing: 2) {
                Text("Debug")
                    .font(.system(size: 10, weight: .light))
                HStack(alignment: .bottom) {
                    Picker(selection: $selectedFormat, label: Text("")) {
                        ForEach(DisplayFormat.allCases, id: \.self) {
                            Text($0.rawValue)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedFormat, perform: { format in
                        selectedWebView?.showAs(format)
                    })
                    .onChange(of: selectedWebView, perform: { webView in
                        selectedFormat = selectedWebView?.selectedFormat ?? .Formatted
                    })
                }
                .scaledToFit()
            }
        }
    }

    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, selectedFormat: Binding<DisplayFormat>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        _selectedFormat = selectedFormat
    }
    
}

struct DebugToolbar_Previews: PreviewProvider {
    static var previews: some View {
        DebugToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil), selectedFormat: .constant(.Formatted))
    }
}
