#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -module-cache-path build/module-cache \
    Sources/Usage.swift Sources/Providers.swift Sources/PanelPlacement.swift Tests/main.swift -o build/usage-tests
build/usage-tests "$@"
