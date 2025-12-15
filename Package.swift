// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "WeChatTweak",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "wechattweak",
            targets: [
                "WeChatTweak"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.0"),
        .package(url: "https://github.com/readium/GCDWebServer.git", from: "3.5.5"),
    ],
    targets: [
            .target(
                name: "WeChatTweakObjC",
                dependencies: [
                    .product(name: "GCDWebServer", package: "GCDWebServer"),
                ],
                path: "Sources/WeChatTweakObjC",
                publicHeadersPath: "."   
            ),
            .executableTarget(
                name: "WeChatTweak",
                dependencies: [
                    "WeChatTweakObjC",
                    .product(name: "ArgumentParser", package: "swift-argument-parser")
                ],
                path: "Sources/WeChatTweak"
            )
            
        ]
)
