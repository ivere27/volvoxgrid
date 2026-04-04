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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.5.0/VolvoxGridPlugin.xcframework.zip",
            checksum: "ea33d6dadaa8b44d4be2cf688d9467c359a571bdece3ab91ebbd1adb1d3e454d"
        ),
    ]
)
