// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VolvoxGrid",
    products: [
        .library(name: "VolvoxGrid", targets: ["VolvoxGridPlugin"]),
    ],
    targets: [
        .binaryTarget(
            name: "VolvoxGridPlugin",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.1.5/VolvoxGridPlugin.xcframework.zip",
            checksum: "bda368ede0f446697b77eb6b7256111150439baa057a79865437af7fb5aa2031"
        ),
    ]
)
