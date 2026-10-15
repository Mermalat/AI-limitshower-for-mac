#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")"
version="$(cat VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Geçersiz VERSION' >&2; exit 1; }
case "${1:-}" in
    '') architectures=("$(uname -m)"); output=build ;;
    --universal) architectures=(arm64 x86_64); output=build/universal ;;
    *) echo 'Kullanım: ./build.sh [--universal]' >&2; exit 1 ;;
esac
app="$(pwd)/$output/AIlimitshower.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build/module-cache
temporary="$(mktemp -d build/binaries.XXXXXX)"
trap 'rm -rf "$temporary"' EXIT
binaries=()
for architecture in "${architectures[@]}"; do
    binary="$temporary/TopBarClaudeCodexLimits-$architecture"
    xcrun swiftc -swift-version 5 -O -module-cache-path build/module-cache \
        -target "$architecture-apple-macosx13.0" \
        Sources/TokenHistory.swift Sources/Localization.swift Sources/Usage.swift Sources/Providers.swift Sources/PanelPlacement.swift Sources/App.swift \
        -o "$binary"
    binaries+=("$binary")
done
if [ "${#binaries[@]}" -eq 2 ]; then
    xcrun lipo -create "${binaries[@]}" -output "$app/Contents/MacOS/TopBarClaudeCodexLimits"
else
    cp "${binaries[0]}" "$app/Contents/MacOS/TopBarClaudeCodexLimits"
fi
cp Assets/*.icns Assets/*.png "$app/Contents/Resources/"
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleExecutable</key><string>TopBarClaudeCodexLimits</string>
    <key>CFBundleIdentifier</key><string>com.mermalat.TopBarClaudeCodexLimits</string>
    <key>CFBundleName</key><string>AIlimitshower</string>
    <key>CFBundleDisplayName</key><string>AIlimitshower</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>$version</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
echo "Hazır: $app"
