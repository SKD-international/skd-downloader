// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "skd-downloader",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SKDDownloaderNative", targets: ["SKDDownloaderNativeApp"]),
    ],
    targets: [
        .target(name: "DownloaderCore"),
        .target(name: "DownloaderUI", dependencies: ["DownloaderCore"]),
        .executableTarget(name: "SKDDownloaderNativeApp", dependencies: ["DownloaderUI"]),
        .testTarget(
            name: "DownloaderCoreTests",
            dependencies: ["DownloaderCore"],
            path: "tests/DownloaderCoreTests"
        ),
    ]
)
