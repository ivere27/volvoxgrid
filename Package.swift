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
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.8/VolvoxGrid.xcframework.zip",
            checksum: "0ecddbd7c91641e543f9f587bfbab8b4adc64256e912b0585682aec4312a9602"
        ),
        .binaryTarget(
            name: "VolvoxGridLite",
            url: "https://github.com/ivere27/volvoxgrid/releases/download/v0.8.8/VolvoxGridLite.xcframework.zip",
            checksum: "f1335b597fc50e194cc7ba52a15f6b7c49fdfd0dec5de85cab950adaef5c8ca1"
        ),
    ]
)
