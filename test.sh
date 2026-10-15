#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache \
    Sources/TokenHistory.swift Sources/Localization.swift Sources/Usage.swift Sources/Providers.swift Sources/PanelPlacement.swift Tests/main.swift -o build/usage-tests
build/usage-tests "$@"
xcrun swiftc -swift-version 5 -D TESTING -parse-as-library -module-cache-path build/module-cache \
    Sources/TokenHistory.swift Sources/Localization.swift Sources/Usage.swift Sources/Providers.swift Sources/PanelPlacement.swift Sources/App.swift Tests/StoreTests.swift -o build/store-tests
cp Assets/*.png build/
build/store-tests

xcrun swiftc -swift-version 5 -O -module-cache-path build/module-cache \
    Sources/Usage.swift Sources/TokenHistory.swift Tests/MemoryTests.swift -o build/memory-tests
build/memory-tests
