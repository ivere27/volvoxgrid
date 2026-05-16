// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VolvoxGrid",
    products: [
        .library(name: "VolvoxGrid", targets: ["VolvoxGrid"]),
        .library(name: "VolvoxGridLite", targets: ["VolvoxGridLite"]),
    ],
    targets: [
        .binaryTarget(
            name: "VolvoxGrid",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.9/VolvoxGrid.xcframework.zip",
            checksum: "db5eb70038c04d577cffb53c9055c2a82668c10e695df0a764eff30d3deba754"
        ),
        .binaryTarget(
            name: "VolvoxGridLite",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.9/VolvoxGridLite.xcframework.zip",
            checksum: "680e7600bfb7c7411eb6593fa3842bd0293adfa7dc4ceafa12effdb156fd1130"
        ),
    ]
)
