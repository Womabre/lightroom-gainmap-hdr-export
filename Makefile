PLUGIN_DIR := plugin/GainMap HDR Heic Export.lrdevplugin
SOURCE_DIR := toGainMapHDR/toGainMapHDR
SWIFT_SOURCES := $(SOURCE_DIR)/main.swift \
	$(wildcard $(SOURCE_DIR)/CustomFilter/*.swift) \
	$(SOURCE_DIR)/Resource/Metadata.swift
METAL_SOURCES := $(wildcard $(SOURCE_DIR)/CustomFilter/*.ci.metal)
METAL_MODULE_CACHE := build/metal-module-cache
SWIFT_MODULE_CACHE := build/swift-module-cache

.PHONY: all build test package clean

all: build

build:
	mkdir -p "$(PLUGIN_DIR)"
	mkdir -p "$(METAL_MODULE_CACHE)"
	mkdir -p "$(SWIFT_MODULE_CACHE)"
	@if ! xcrun --find metal >/dev/null 2>&1; then \
		echo "The Metal compiler is unavailable. Install Xcode and select it with xcode-select before building." >&2; \
		exit 1; \
	fi
	@set -e; for source in $(METAL_SOURCES); do \
		name=$$(basename "$$source" .ci.metal); \
		xcrun -sdk macosx metal -fcikernel -fmodules-cache-path="$(METAL_MODULE_CACHE)" "$$source" -o "$(PLUGIN_DIR)/$$name.ci.metallib"; \
	done
	swiftc -module-cache-path "$(SWIFT_MODULE_CACHE)" $(SWIFT_SOURCES) -o "$(PLUGIN_DIR)/toGainMapHDR"
	chmod 755 "$(PLUGIN_DIR)/toGainMapHDR"

test: build
	./tests/run-integration.sh "$(PLUGIN_DIR)/toGainMapHDR"

package: build
	mkdir -p build
	ditto -c -k --norsrc --keepParent "$(PLUGIN_DIR)" "build/GainMap HDR Heic Export.lrdevplugin.zip"

clean:
	rm -f "$(PLUGIN_DIR)/toGainMapHDR" "$(PLUGIN_DIR)"/*.ci.metallib
	rm -rf build
