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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.7.1/VolvoxGridPlugin.xcframework.zip",
            checksum: "8861e5b5aa591d334a8a18d3a2b46c33354b9f50db3311429ea9789af3181d13"
        ),
    ]
)
