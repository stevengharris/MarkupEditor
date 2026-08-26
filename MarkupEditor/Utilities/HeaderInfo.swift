//
//  HeaderInfo.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/26/26.
//

import Foundation

/// Identifies a single H1-H6 header in the document, as returned by `MarkupWKWebView.getHeaders()`.
///
/// `hTag` and `index` together identify the header the same way `MarkupWKWebView.insertInternalLink(hTag:index:)`
/// does: `index` is the header's position among other headers sharing `hTag` in document order.
///
/// `id` is the header's current id attribute, or nil if it hasn't been assigned one yet (assignment
/// happens lazily, the first time a link is made to that header).
public struct HeaderInfo: Codable, Sendable, Equatable {
    public let hTag: String
    public let index: Int
    public let text: String
    public let id: String?
}
