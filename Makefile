# glosa-tools Makefile
# Requires Apple Silicon (arm64) architecture.
#
# Build flags:
#   -skipMacroValidation         — mlx-swift-lm's MLXHuggingFace (pulled via SwiftBruja)
#                                  uses a Swift macro plugin that must be trust-approved;
#                                  headless xcodebuild cannot answer the prompt.
#   -skipPackagePluginValidation — mlx-swift ships a build-tool plugin with the same gate.

.PHONY: help check-arch resolve build test test-ci clean install release dist format

SCHEME_PACKAGE = glosa-tools-Package
SCHEME_CLI     = glosa
DEST           = platform=macOS,arch=arm64
MACRO_FLAG     = -skipMacroValidation -skipPackagePluginValidation
DERIVED_DATA   = $(HOME)/Library/Developer/Xcode/DerivedData
BUNDLE         = glosa-tools_GlosaDirector.bundle

# Version for `dist`. Override explicitly in CI (`make dist VERSION=0.5.0`); the
# release workflow does this from the tag. Falls back to the latest git tag,
# then 0.0.0. NOTE: it must be a make-level default (not `git describe | sed ||
# echo` inside the recipe) because a pipeline's exit status is the last stage's
# (sed always succeeds), so the `|| echo` fallback never fires and VERSION ends
# up empty — producing a `glosa--arm64-macos.tar.gz` mis-named tarball.
VERSION       ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')

help:
	@echo "glosa-tools Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make build     - Build the package (Apple Silicon only)"
	@echo "  make test      - Run all tests (Apple Silicon only)"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make resolve   - Resolve package dependencies"
	@echo "  make install   - Install glosa CLI to bin/ directory"
	@echo "  make release   - Build release binary"
	@echo "  make dist      - Create distributable tarball for Homebrew"
	@echo "  make format    - Format Swift source files with swift-format"
	@echo ""
	@echo "Requirements:"
	@echo "  - Apple Silicon (arm64) architecture"
	@echo "  - Xcode 26 / Swift 6.2 or later"

# Fail if not Apple Silicon
check-arch:
	@ARCH=$$(uname -m); \
	if [ "$$ARCH" != "arm64" ]; then \
		echo "❌ Error: This project requires Apple Silicon (arm64)"; \
		echo "   Current architecture: $$ARCH"; \
		exit 1; \
	fi

resolve: check-arch
	@echo "🔄 Resolving package dependencies..."
	xcodebuild -resolvePackageDependencies -scheme $(SCHEME_PACKAGE)

build: check-arch
	@echo "🔨 Building glosa-tools..."
	xcodebuild build \
		-scheme $(SCHEME_PACKAGE) \
		-destination '$(DEST)' \
		$(MACRO_FLAG)

test: check-arch
	@echo "🧪 Running glosa-tools tests..."
	xcodebuild test \
		-scheme $(SCHEME_PACKAGE) \
		-destination '$(DEST)' \
		$(MACRO_FLAG) \
		-enableCodeCoverage YES

# CI test gate: model-free tests only. GlosaDirectorTests exercise the LLM
# StageDirector and require a cached model download, so they are skipped here
# (wire them via the acervo-integration-ci pattern when model caching is added).
test-ci: check-arch
	@echo "🧪 Running model-free tests (GlosaAnnotationTests)..."
	xcodebuild test \
		-scheme $(SCHEME_PACKAGE) \
		-destination '$(DEST)' \
		$(MACRO_FLAG) \
		-only-testing:GlosaAnnotationTests

clean:
	@echo "🧹 Cleaning build artifacts..."
	xcodebuild clean -scheme $(SCHEME_PACKAGE) -destination '$(DEST)' 2>/dev/null || true
	rm -rf .build bin dist

# Build the release binary
release: check-arch
	@echo "🔨 Building glosa CLI for release..."
	xcodebuild build \
		-scheme $(SCHEME_CLI) \
		-destination '$(DEST)' \
		-configuration Release \
		$(MACRO_FLAG)

# Install CLI (binary + resource bundle) to project bin/
install: release
	@echo "📦 Installing glosa to bin/..."
	@mkdir -p bin
	@PRODUCT_DIR=$$(find "$(DERIVED_DATA)"/glosa-tools-*/Build/Products/Release -maxdepth 1 -name glosa -type f 2>/dev/null | head -1 | xargs dirname); \
	if [ -z "$$PRODUCT_DIR" ] || [ ! -f "$$PRODUCT_DIR/glosa" ]; then \
		echo "❌ Error: Could not find built glosa executable"; exit 1; \
	fi; \
	cp "$$PRODUCT_DIR/glosa" bin/glosa; \
	chmod +x bin/glosa; \
	if [ ! -d "$$PRODUCT_DIR/$(BUNDLE)" ]; then \
		echo "❌ Error: $(BUNDLE) not found next to the binary"; exit 1; \
	fi; \
	rm -rf "bin/$(BUNDLE)"; \
	cp -R "$$PRODUCT_DIR/$(BUNDLE)" bin/; \
	echo "✅ Installed glosa + $(BUNDLE) to bin/"

# Create distributable tarball (binary + resource bundle) for Homebrew
dist: release
	@echo "📦 Creating distribution tarball..."
	@mkdir -p dist bin
	@V="$(VERSION)"; [ -z "$$V" ] && V="0.0.0"; \
	PRODUCT_DIR=$$(find "$(DERIVED_DATA)"/glosa-tools-*/Build/Products/Release -maxdepth 1 -name glosa -type f 2>/dev/null | head -1 | xargs dirname); \
	if [ -z "$$PRODUCT_DIR" ] || [ ! -f "$$PRODUCT_DIR/glosa" ]; then \
		echo "❌ Error: Could not find built glosa executable"; exit 1; \
	fi; \
	if [ ! -d "$$PRODUCT_DIR/$(BUNDLE)" ]; then \
		echo "❌ Error: $(BUNDLE) not found next to the binary — refusing to ship an incomplete tarball"; exit 1; \
	fi; \
	cp "$$PRODUCT_DIR/glosa" bin/; \
	rm -rf "bin/$(BUNDLE)"; \
	cp -R "$$PRODUCT_DIR/$(BUNDLE)" bin/; \
	TARBALL="dist/glosa-$$V-arm64-macos.tar.gz"; \
	tar -C bin -czf "$$TARBALL" glosa "$(BUNDLE)"; \
	SHA256=$$(shasum -a 256 "$$TARBALL" | cut -d' ' -f1); \
	echo ""; \
	echo "=== Distribution Package ==="; \
	echo "Tarball: $$TARBALL"; \
	echo "SHA256:  $$SHA256"; \
	ls -lh "$$TARBALL"

format:
	@echo "✨ Formatting Swift source files..."
	swift format -i -r Sources/ Tests/
