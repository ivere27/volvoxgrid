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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.6.0/VolvoxGridPlugin.xcframework.zip",
            checksum: "ec3de58de75a9e631e18ba396570acf051b67dc5b3295c6e6542833de9a4eefb"
        ),
    ]
)
