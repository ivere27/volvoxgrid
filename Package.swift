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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.9/VolvoxGrid.xcframework.zip",
            checksum: "db5eb70038c04d577cffb53c9055c2a82668c10e695df0a764eff30d3deba754"
        ),
        .binaryTarget(
            name: "VolvoxGridLiteXCFramework",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.9/VolvoxGridLite.xcframework.zip",
            checksum: "680e7600bfb7c7411eb6593fa3842bd0293adfa7dc4ceafa12effdb156fd1130"
        ),
        .target(
            name: "VolvoxGrid",
            dependencies: ["VolvoxGridLiteXCFramework"],
            path: "swift/Sources/VolvoxGrid"
        ),
    ]
)

#endif
