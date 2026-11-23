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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.13/VolvoxGrid.xcframework.zip",
            checksum: "35c2bb9190e4d066a8e85bef9eb2ffa21d3236b94b88e941b696e0f8162bd915"
        ),
        .binaryTarget(
            name: "VolvoxGridLiteXCFramework",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.13/VolvoxGridLite.xcframework.zip",
            checksum: "a23c3f8572c3e40e298521aefff59a84eaf4cc5826f73da5a09a3e734cab81ec"
        ),
        .target(
            name: "VolvoxGrid",
            dependencies: ["VolvoxGridLiteXCFramework"],
            path: "swift/Sources/VolvoxGrid"
        ),
    ]
)

#endif
