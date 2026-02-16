// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarkupEditor",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MarkupEditor",
            targets: ["MarkupEditor"]),
    ],
    dependencies: [],
    targets: [
        // Resources include the html and packaged web component markup-editor.js.
        // Note that since the platforms are .iOS and .macCatalyst, they need to be
        // built using xcodebuild, identifying the "MarkupEditor" scheme and target
        // names from the project, which are the same as specified below.
        .target(
            name: "MarkupEditor",
            dependencies: [],
            path: "MarkupEditor",
            resources: [.process("Resources")]),
        .target(
            name: "SharedTest",
            dependencies: ["MarkupEditor"],
            path: "MarkupEditorTests/SharedTest"),
        .testTarget(
            name: "BaseTests",
            dependencies: ["MarkupEditor", "SharedTest"],
            path: "MarkupEditorTests/BaseTests",
            resources: [.process("Data")]),
        .testTarget(
            name: "SwiftTests",
            dependencies: ["MarkupEditor", "SharedTest"],
            path: "MarkupEditorTests/SwiftTests"),
    ]
)
