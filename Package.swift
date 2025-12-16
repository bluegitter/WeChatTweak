// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "WeChatTweak",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        // 注入用动态库
        .library(
            name: "wechattweak",
            type: .dynamic,
            targets: ["WeChatTweak"]
        ),
        // 命令行工具（用于 patch/resign/version）
        .executable(
            name: "wechattweak_cli",
            targets: ["WeChatTweakCLI"]
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

        // dylib target：不要包含 main.swift / @main / ArgumentParser 主程序
        .target(
            name: "WeChatTweak",
            dependencies: [
                "WeChatTweakObjC"
            ],
            path: "Sources/WeChatTweak"
        ),

        // CLI target：把原来的 ArgumentParser + Tweak.main() 全部放这里
        .executableTarget(
            name: "WeChatTweakCLI",
            dependencies: [
                "WeChatTweak",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/WeChatTweakCLI"
        )
    ]
)
