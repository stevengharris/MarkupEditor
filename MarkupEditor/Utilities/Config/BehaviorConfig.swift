//
//  BehaviorConfig.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/26.
//

import Foundation

public struct BehaviorConfig: Codable {
    public let focusAfterLoad: Bool
    public let selectImage: Bool
    public let insertLink: Bool
    public let insertImage: Bool

    private static func all() throws -> BehaviorConfig {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: MarkupWKWebView.self)
        #endif
        guard let path = bundle.path(forResource: "behaviorconfig", ofType: "json") else {
            fatalError("Behavior config could not be found in bundle")
        }
        let url = URL(filePath: path, directoryHint: .notDirectory)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(BehaviorConfig.self, from: data)
    }

    public static func load() -> BehaviorConfig? {
        return try? all()
    }

    public static func none() -> BehaviorConfig {
        BehaviorConfig(
            focusAfterLoad: false,
            selectImage: false,
            insertLink: false,
            insertImage: false
        )
    }
}
