// swift-tools-version:5.9
import PackageDescription

// VolvoxGrid Swift package.
//
// Two branches share the same Swift sources under swift/Sources/VolvoxGrid:
//
//   • Apple (macOS / iOS / tvOS) — the default branch. Statically linked
//     via the prebuilt VolvoxGridLite XCFramework. Consumers do nothing
//     beyond `import VolvoxGrid`.
//
//   • Linux — for in-tree development and the TUI sample. The native
//     engine is loaded at runtime via dlopen of `libvolvoxgrid.so`,
//     controlled by the `VOLVOXGRID_LIBRARY_PATH` environment variable.
//     This branch also builds the `VolvoxGridTuiSample` executable
//     (the Swift counterpart of `dotnet-tui-run-release`). Apple targets
//     do not need this executable — they use the SwiftUI demos under
//     swift/Examples instead.

#if os(Linux)

let package = Package(
    name: "VolvoxGrid",
    products: [
        .library(name: "VolvoxGrid", targets: ["VolvoxGrid"]),
        .executable(name: "VolvoxGridTuiSample", targets: ["VolvoxGridTuiSample"]),
    ],
    targets: [
        .target(
            name: "VolvoxGrid",
            path: "swift/Sources/VolvoxGrid",
            exclude: ["Rendering"]
        ),
        .executableTarget(
            name: "VolvoxGridTuiSample",
            dependencies: ["VolvoxGrid"],
            path: "swift/Sources/VolvoxGridTuiSample"
        ),
    ]
)

#else

let package = Package(
    name: "VolvoxGrid",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
    ],
    products: [
        // Swift wrapper. Recommended entry point for iOS / macOS apps —
        // `import VolvoxGrid` then `let client = try VolvoxGridClient()`.
        // Backed by the Lite XCFramework (no SwiftProtobuf or grpc-swift).
        .library(name: "VolvoxGrid", targets: ["VolvoxGrid"]),

        // Raw XCFramework binaries, for callers who want to bring their
        // own gRPC / SwiftProtobuf stack and talk to the engine directly.
        .library(name: "VolvoxGridXCFramework", targets: ["VolvoxGridXCFramework"]),
        .library(name: "VolvoxGridLiteXCFramework", targets: ["VolvoxGridLiteXCFramework"]),
    ],
    targets: [
        .binaryTarget(
            name: "VolvoxGridXCFramework",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.11/VolvoxGrid.xcframework.zip",
            checksum: "96cd9803b75de9cdd712805ad3800c72f09a467ddafc5a5a9d9f93a487478bb8"
        ),
        .binaryTarget(
            name: "VolvoxGridLiteXCFramework",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.11/VolvoxGridLite.xcframework.zip",
            checksum: "1a1558cde059fc54b0189dcddab49758dc9ee9a90a90420b405e758e00971a45"
        ),
        .target(
            name: "VolvoxGrid",
            dependencies: ["VolvoxGridLiteXCFramework"],
            path: "swift/Sources/VolvoxGrid"
        ),
    ]
)

#endif
