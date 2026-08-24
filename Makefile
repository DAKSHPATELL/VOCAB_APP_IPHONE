# Everything below the line marked "needs macOS" runs anywhere Python 3 does.
SIMULATOR ?= platform=iOS Simulator,name=iPhone 16 Pro
SCHEME    ?= VocabWallpaper
PROJECT   ?= VocabWallpaper.xcodeproj

.PHONY: help vocab icon project validate check all build test clean

help:
	@echo "vocab      rebuild vocabulary.json from tools/build_vocabulary.py"
	@echo "icon       re-render the 1024px app icon"
	@echo "project    regenerate $(PROJECT) from the folders on disk"
	@echo "validate   parse the pbxproj and look for dangling references"
	@echo "check      structural check across every Swift file"
	@echo "all        vocab + icon + project + validate + check"
	@echo "build      xcodebuild for the simulator            (needs macOS)"
	@echo "test       xcodebuild test for VocabKit            (needs macOS)"

vocab:
	python3 tools/build_vocabulary.py

icon:
	python3 tools/make_appicon.py

project:
	python3 tools/generate_xcodeproj.py

validate:
	python3 tools/validate_pbxproj.py

check:
	python3 tools/check_swift_balance.py

all: vocab icon project validate check

# ---------------------------------------------------------------- needs macOS
build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination '$(SIMULATOR)' -configuration Debug build

test:
	swift test --package-path VocabKit

clean:
	rm -rf build DerivedData
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean || true
