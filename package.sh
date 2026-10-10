#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")"
version="$(cat VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Geçersiz VERSION' >&2; exit 1; }
./test.sh
./build.sh --universal
app=build/universal/TopBarClaudeCodexLimits.app
binary="$app/Contents/MacOS/TopBarClaudeCodexLimits"
architectures="$(xcrun lipo -archs "$binary")"
[[ "$architectures" == 'arm64 x86_64' || "$architectures" == 'x86_64 arm64' ]] || {
    echo "Universal mimariler eksik: $architectures" >&2; exit 1;
}
codesign --verify --deep --strict "$app"
mkdir -p dist
staging="$(mktemp -d build/dmg.XXXXXX)"
trap 'rm -rf "$staging"' EXIT
ditto "$app" "$staging/TopBarClaudeCodexLimits.app"
ln -s /Applications "$staging/Applications"
cp docs/INSTALL.md "$staging/Kurulum.md"
cp LICENSE THIRD_PARTY_NOTICES.md "$staging/"
dmg="dist/TopBarClaudeCodexLimits-$version-universal.dmg"
sources="dist/TopBarClaudeCodexLimits-$version-source.tar.gz"
hdiutil create -volname "Claude & Codex Limits $version" \
    -srcfolder "$staging" -format UDZO -fs HFS+ -ov "$dmg"
hdiutil verify "$dmg"
COPYFILE_DISABLE=1 tar -czf "$sources" \
    Sources Tests Assets docs README.md LICENSE THIRD_PARTY_NOTICES.md \
    VERSION .gitignore build.sh run.sh test.sh package.sh CHANGELOG.md
(
    cd dist
    shasum -a 256 "$(basename "$dmg")" "$(basename "$sources")" > SHA256SUMS.txt
)
echo "Hazır: $dmg"
echo "Kaynak kod: $sources"
