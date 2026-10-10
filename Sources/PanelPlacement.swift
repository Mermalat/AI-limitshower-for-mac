// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Mermalat

import Foundation
import CoreGraphics

enum PanelPlacement {
    static func fit(_ frame: CGRect, inside visibleFrame: CGRect) -> CGRect {
        let bounds = visibleFrame.insetBy(dx: 8, dy: 8)
        var result = frame
        result.size.width = min(frame.width, bounds.width)
        result.size.height = min(frame.height, bounds.height)
        result.origin.x = min(max(frame.minX, bounds.minX), bounds.maxX - result.width)
        result.origin.y = min(max(frame.minY, bounds.minY), bounds.maxY - result.height)
        return result
    }
}
