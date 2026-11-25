#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/prepare-macos-icon.py
bash scripts/check-models.sh
xcodegen generate
BUILD_DIR="$PWD/build/macOS"
mkdir -p "$BUILD_DIR" dist

xcodebuild build-for-testing -project PlantaoNaMao.xcodeproj -scheme PlantaoNaMaoMac \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO

# Test builds use an ad hoc signature and no restricted App Group entitlement.
# This validates the app UI, not authorization of WidgetKit's shared container.
cat > "$BUILD_DIR/test.entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.get-task-allow</key><true/>
<key>com.apple.security.cs.disable-library-validation</key><true/>
</dict></plist>
PLIST
while IFS= read -r -d '' bundle; do
  codesign --force --deep --sign - --entitlements "$BUILD_DIR/test.entitlements" "$bundle"
done < <(find "$BUILD_DIR/Build/Products/Debug" -depth \( -name '*.app' -o -name '*.appex' -o -name '*.xctest' \) -type d -print0)

xcodebuild test-without-building -project PlantaoNaMao.xcodeproj -scheme PlantaoNaMaoMac \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath "$BUILD_DIR" \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 180 \
  -resultBundlePath "$BUILD_DIR/MacTests.xcresult" CODE_SIGNING_ALLOWED=NO

xcodebuild build -project PlantaoNaMao.xcodeproj -scheme PlantaoNaMaoMac \
  -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$BUILD_DIR" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO

ditto "$BUILD_DIR/Build/Products/Release/PlantaoNaMao.app" dist/PlantaoNaMao.app
test -d dist/PlantaoNaMao.app/Contents/PlugIns/PlantaoNaMaoMacWidgets.appex
lipo dist/PlantaoNaMao.app/Contents/MacOS/PlantaoNaMao -verify_arch arm64 x86_64
lipo dist/PlantaoNaMao.app/Contents/PlugIns/PlantaoNaMaoMacWidgets.appex/Contents/MacOS/PlantaoNaMaoMacWidgets -verify_arch arm64 x86_64
# The downloadable test build runs without an Apple Developer account. Real App
# Group authorization for the widget must come from the owner's Apple signature.
codesign --force --deep --sign - dist/PlantaoNaMao.app
codesign --verify --deep --strict dist/PlantaoNaMao.app
ditto -c -k --sequesterRsrc --keepParent dist/PlantaoNaMao.app dist/PlantaoNaMao-macOS-1.6.zip
mkdir -p "$BUILD_DIR/dmg"
ditto dist/PlantaoNaMao.app "$BUILD_DIR/dmg/PlantaoNaMao.app"
ln -s /Applications "$BUILD_DIR/dmg/Applications"
hdiutil create -volname 'Plantão na Mão' -srcfolder "$BUILD_DIR/dmg" -ov -format UDZO dist/PlantaoNaMao-macOS-1.6.dmg
shasum -a 256 dist/PlantaoNaMao-macOS-1.6.zip dist/PlantaoNaMao-macOS-1.6.dmg > dist/SHA256SUMS.txt
