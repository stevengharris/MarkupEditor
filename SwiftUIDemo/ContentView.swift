//
//  ContentView.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 3/9/21.
//

import SwiftUI
import MarkupEditor

struct ContentView: View {
   
    class MockStateHolder: MarkupStateHolder {
        @Published var selectedWebView: MarkupWKWebView? = nil
        @Published var selectionState: SelectionState = SelectionState()
    }

    private var mockStateHolder: MockStateHolder
    var body: some View {
        VStack(spacing: 0) {
            MarkupToolbar(markupStateHolder: mockStateHolder, markupUIDelegate: self)
            MarkupWebView(markupStateHolder: mockStateHolder, markupEventDelegate: self, initialContent: "<p>Hello <b>bold</b> <i>SwiftUI</i> world!</p>")
        }
    }
    
    init() {
        mockStateHolder = MockStateHolder()
    }
    
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        ContentView()
    }
    
}

extension ContentView: MarkupEventDelegate {
    
    func markupSelectionChanged(_ view: MarkupWKWebView, selectionState: SelectionState) {
        // If the selection is in a link and not across multiple characters, then let the markupUIDelegate decide what to do.
        // The default behavior for the markupUIDelegate is to open the href in selectionState.
        if selectionState.isFollowable {
            markupLinkSelected(view, selectionState: selectionState)
        }
        // Call markupImageSelected in any event, to clear the scaleStepper if needed
        markupImageSelected(view, selectionState: selectionState)
    }

}

extension ContentView: MarkupUIDelegate {
    
}
