//
//  ContentView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 3/9/21.
//

import SwiftUI
import MarkupEditor

struct ContentView: View {
   
    @StateObject var selectionState = SelectionState()
    @State var selectedWebView: MarkupWKWebView?
    var body: some View {
        VStack(spacing: 0) {
            MarkupToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, markupUIDelegate: self)
            MarkupWebView(selectionState: selectionState, selectedWebView: $selectedWebView, markupEventDelegate: self, initialContent: "<p>Hello <b>bold</b> <i>SwiftUI</i> world!</p>")
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        ContentView()
    }
    
}

extension ContentView: MarkupEventDelegate {
    
    func markupTookFocus(_ view: MarkupWKWebView) {
        selectedWebView = view
    }
    
    func markupClicked(_ view: MarkupWKWebView) {
        // If the selection is in a link and not across multiple characters, then let the markupUIDelegate decide what to do.
        // The default behavior for the markupUIDelegate is to open the href in selectionState.
        if selectionState.isFollowable {
            markupLinkSelected(view, selectionState: selectionState)
        }
        // Call markupImageSelected in any event
        markupImageSelected(view, selectionState: selectionState)
    }

}

extension ContentView: MarkupUIDelegate {
    
}
