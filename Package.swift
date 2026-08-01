// swift-tools-version: 6.2

import Foundation
import PackageDescription

// In CI we always pin to released remotes. Locally, prefer a sibling checkout
// at ../<name> if present so in-flight changes can be exercised end-to-end
// without publishing a release. Falls back to the remote pin if the sibling
// directory is missing, so fresh clones still build.
//
// When this manifest is evaluated as a transitive dependency inside Xcode's
// `SourcePackages/checkouts/` or SwiftPM's `.build/checkouts/`, every other
// dependency lives as a sibling in the same directory. Treating those as
// in-development local paths produces conflicting package identities, so we
// must skip the sibling shortcut in that context.
let manifestDir = (#filePath as NSString).deletingLastPathComponent
let isSPMCheckout =
  manifestDir.contains("/SourcePackages/checkouts/")
  || manifestDir.contains("/.build/checkouts/")
let isCI = ProcessInfo.processInfo.environment["CI"] == "true"
let useLocalSiblings = !isCI && !isSPMCheckout

func sibling(_ name: String, remote: String, from version: Version) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, .upToNextMajor(from: version))
}

/// Same sibling-priority pattern as ``sibling(_:remote:from:)`` but pins to a
/// remote branch when no local sibling exists. Use only when a temporary
/// pre-release dependency on a feature branch is required; switch back to the
/// version-pinned ``sibling(_:remote:from:)`` once the upstream tags a release.
func sibling(_ name: String, remote: String, branch: String) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, branch: branch)
}

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
        sibling(
          "glosa-av",
          remote: "https://github.com/intrusive-memory/glosa-av.git",
          from: "0.5.0"),
        sibling(
          "SwiftCompartido",
          remote: "https://github.com/intrusive-memory/SwiftCompartido.git",
          from: "7.0.5"),
        sibling(
          "SwiftBruja",
          remote: "https://github.com/intrusive-memory/SwiftBruja.git",
          from: "1.7.1"),
        sibling(
          "SwiftAcervo",
          remote: "https://github.com/intrusive-memory/SwiftAcervo.git",
          from: "0.25.0"),
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
