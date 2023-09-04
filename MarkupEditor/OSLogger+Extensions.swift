//
//  OSLogger+Extensions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 9/4/23.
//

import OSLog

extension Logger {

    private static var subsystem = Bundle.main.bundleIdentifier!

    public static let script = Logger(subsystem: subsystem, category: "script")
    public static let coordinator = Logger(subsystem: subsystem, category: "coordinator")
    public static let webview = Logger(subsystem: subsystem, category: "webview")
    public static let test = Logger(subsystem: subsystem, category: "test")
    
}
