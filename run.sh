#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -x build/AIlimitshower.app/Contents/MacOS/TopBarClaudeCodexLimits ]; then
    ./build.sh
fi
open build/AIlimitshower.app
