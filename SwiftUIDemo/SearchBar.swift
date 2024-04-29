//
//  SearchBar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/6/23.
//

import SwiftUI
import MarkupEditor

/// The SearchBar demonstrates how the MarkupEditor search functionality works.
///
/// When using this SearchBar, pressing Enter (aka submit) on the TextField activates the "search mode". When
/// search mode is active, Enter in the MarkupWKWebView is intercepted and interpreted as "search for next". This
/// way you can search and continue to press Enter until you get to the selection you are interested in. Any input
/// other than Enter (including typing, clicking, or touching) terminates search mode. The arrowtriangles on either
/// side of the TextField cause search in that direction but do not activate the search mode.
///
/// Note that by default, search mode is never activated. To activate it, you must use `activate: true` in your
/// call to `MarkupWKWebView.search(for:direction:activate:handler:)`.
struct SearchBar: View {
    @State var searchString: String = ""
    @State var direction: MarkupEditor.FindDirection = .forward
    @FocusState var searchIsFocused: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            ToolbarImageButton(systemName: "arrowtriangle.backward.fill") {
                direction = .backward
                search()
            }
            .contentShape(Rectangle())
            .disabled(searchString.isEmpty)
            HStack(spacing: 4) {
                TextField("", text: $searchString)
                    .textFieldStyle(.roundedBorder)
                    .padding(2)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .onSubmit { search() }
                    .focused($searchIsFocused)
                    .overlay(alignment: .leading) {
                        if (!searchIsFocused && searchString.isEmpty) {
                            (Text(Image(systemName: "magnifyingglass")) + Text(" Search"))
                                .allowsHitTesting(false)
                                .foregroundColor(.gray)
                                .offset(x: 8, y: 0)
                        }
                    }
                    .overlay(alignment: .trailing) {
                        if (!searchString.isEmpty) {
                            Button(action: {
                                cancelSearch()
                            }, label: {
                                Label(title: { Text("Hide")}, icon: { Image(systemName: "xmark.circle.fill") })
                                    .labelStyle(IconOnlyLabelStyle())
                            })
                            .buttonStyle(.plain)
                            .foregroundColor(.gray)
                            .offset(x: -8, y: 0)
                        }
                    }
            }
            .background(Color(.systemBackground))
            ToolbarImageButton(systemName: "arrowtriangle.forward.fill") {
                direction = .forward
                search()
            }
            .contentShape(Rectangle())
            .disabled(searchString.isEmpty)
        }
        .fixedSize(horizontal: false, vertical: true)
        // With buttonStyle and simultaneousGesture, the button action fire
        .simultaneousGesture(TapGesture().onEnded({_ in }))
        .onAppear {
            searchIsFocused = true
        }
        
    }
    
    /// Initiate search for `searchString`, entering into a mode where Enter will find next in the same direction.
    @MainActor
    private func search() {
        guard !searchString.isEmpty, let selectedWebView = MarkupEditor.selectedWebView else { return }
        selectedWebView.search(for: searchString, direction: direction, activate: true)
    }
    
    /// Clear the search string, suppress Enter doing next search, and make sure the selectedWebView is firstResponder.
    @MainActor
    private func cancelSearch() {
        searchString = ""
        guard let selectedWebView = MarkupEditor.selectedWebView else { return }
        selectedWebView.cancelSearch()
        selectedWebView.becomeFirstResponder()
    }
    
}
