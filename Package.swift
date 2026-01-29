// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarkupEditor",
    platforms: [
        .macOS(.v13),
        .macCatalyst(.v16),
        .iOS(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MarkupEditor",
            targets: ["MarkupEditor"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Resources include the html, css, and js files that are loaded when a MarkupWKWebView is instantiated
        .target(
            name: "MarkupEditor",
            dependencies: [],
            path: "MarkupEditor",
            resources: [.process("Resources")]),
        .testTarget(
            name: "BaseTests",
            dependencies: ["MarkupEditor"],
            path: "MarkupEditorTests/BaseTests"),
        .testTarget(
            name: "SwiftTests",
            dependencies: ["MarkupEditor"],
            path: "MarkupEditorTests/SwiftTests"),
    ]
)

/** Seems to cause problems, but will leave here in case it can be enabled
 for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableExperimentalFeature("StrictConcurrency"))
    target.swiftSettings = settings
 }
 */
