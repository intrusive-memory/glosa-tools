// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "glosa-tools",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "GlosaAnnotation", targets: ["GlosaAnnotation"]),
        .library(name: "GlosaDirector", targets: ["GlosaDirector"]),
        .executable(name: "glosa", targets: ["glosa"]),
    ],
    dependencies: [
        // glosa-av vends the GlosaCore library. The floor is the forthcoming
        // glosa-av next-minor release (tagged in Sortie 6); during the mission
        // the sibling helper resolves this to the local ../glosa-av checkout.
        .package(url: "https://github.com/intrusive-memory/glosa-av.git", .upToNextMajor(from: "0.9.1")),
        .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", .upToNextMajor(from: "7.4.0")),
        .package(url: "https://github.com/intrusive-memory/SwiftBruja.git", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/intrusive-memory/SwiftAcervo.git", .upToNextMajor(from: "0.25.0")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.1"),
        .package(url: "https://github.com/jkandzi/Progress.swift", from: "0.4.0"),
        // NOTE: no swift-tokenizers pin. SwiftBruja migrated its tokenizer seam to
        // huggingface/swift-transformers (which vends the `Tokenizers` target) and
        // dropped the DePasqualeOrg swift-tokenizers / swift-tokenizers-mlx forks.
        // Pinning swift-tokenizers here dragged a *second* `Tokenizers` target into
        // the graph and broke resolution ("conflicting name: 'Tokenizers'"). The
        // concrete tokenizer now resolves transitively via SwiftBruja.
    ],
    targets: [
        // MARK: - GlosaAnnotation (GlosaCore + SwiftCompartido)
        .target(
            name: "GlosaAnnotation",
            dependencies: [
                .product(name: "GlosaCore", package: "glosa-av"),
                .product(name: "SwiftCompartido", package: "SwiftCompartido"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),

        // MARK: - GlosaDirector (GlosaAnnotation + SwiftBruja + SwiftAcervo)
        .target(
            name: "GlosaDirector",
            dependencies: [
                "GlosaAnnotation",
                .product(name: "SwiftBruja", package: "SwiftBruja"),
                .product(name: "SwiftAcervo", package: "SwiftAcervo"),
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),

        // MARK: - glosa CLI
        .executableTarget(
            name: "glosa",
            dependencies: [
                "GlosaDirector",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftAcervo", package: "SwiftAcervo"),
                .product(name: "Progress", package: "Progress.swift"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "GlosaAnnotationTests",
            dependencies: [
                "GlosaAnnotation",
                .product(name: "GlosaCore", package: "glosa-av"),
                .product(name: "SwiftCompartido", package: "SwiftCompartido"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "GlosaDirectorTests",
            dependencies: [
                "GlosaDirector",
                "GlosaAnnotation",
                .product(name: "GlosaCore", package: "glosa-av"),
                .product(name: "SwiftCompartido", package: "SwiftCompartido"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
