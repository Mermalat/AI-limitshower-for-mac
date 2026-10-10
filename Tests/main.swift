// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Mermalat

import Foundation
import CoreGraphics

func json(_ text: String) throws -> [String: Any] { try UsageParser.object(Data(text.utf8)) }
func rejects(_ body: () throws -> Void) {
    do { try body(); fatalError("Geçersiz veri kabul edildi") } catch { }
}

let codex = try UsageParser.codex(json("""
{"rateLimits":{"primary":{"usedPercent":99}},"rateLimitsByLimitId":{"codex":{"planType":"plus","primary":{"usedPercent":24,"windowDurationMins":300,"resetsAt":1791650228},"secondary":{"usedPercent":9,"windowDurationMins":10080}}}}
"""))
assert(codex.remaining == 76)
assert(codex.windows.map(\.title) == ["5 saatlik", "Haftalık"])
assert(codex.windows[0].reset?.timeIntervalSince1970 == 1791650228)
assert(codex.plan == "plus")
let legacy = try UsageParser.codex(json("""
{"rateLimits":{"primary":{"usedPercent":0},"secondary":{"usedPercent":80}}}
"""))
assert(legacy.remaining == 20)
assert(legacy.windows[0].percentText == "100%")
rejects { _ = try UsageParser.codex(json("{}")) }
rejects { _ = try UsageParser.codex(json("""
{"rateLimits":{"primary":{"usedPercent":null},"secondary":{"usedPercent":true}}}
""")) }

let claudeData = Data("""
{"five_hour":{"utilization":0.42,"resets_at":"2026-10-10T16:00:00.521744+00:00"},"seven_day":{"utilization":40,"resets_at":"2026-10-15T10:00:00Z"},"seven_day_opus":null,"seven_day_sonnet":{"utilization":99,"resets_at":null}}
""".utf8)
let claude = try UsageParser.claude(claudeData, plan: "pro")
assert(claude.windows.count == 3)
assert(abs(claude.windows[0].remaining - 99.58) < 0.00001)
assert(claude.remaining == 60) // Sonnet does not replace the general limit.
assert(claude.windows[0].reset != nil && claude.windows[1].reset != nil)
assert(claude.windows[2].reset == nil)
rejects { _ = try UsageParser.claude(Data("{\"five_hour\":null}".utf8), plan: nil) }
rejects { _ = try UsageParser.claude(Data("{\"five_hour\":{\"utilization\":-1}}".utf8), plan: nil) }
assert(UsageWindow(id: "test", title: "", used: 120, reset: nil).remaining == 0)
assert(UsageParser.number(true) == nil)
assert(UsageParser.number(Double.nan) == nil)

let future = Int(Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000)
let validCredentials = Data("""
{"claudeAiOauth":{"accessToken":"fake-token-for-test","expiresAt":\(future),"scopes":["user:profile"],"subscriptionType":"pro"},"mcpOAuth":{"irrelevant":{"accessToken":"wrong-token"}}}
""".utf8)
let credentials = try UsageParser.claudeCredentials(validCredentials)
assert(credentials.token == "fake-token-for-test")
rejects { _ = try UsageParser.claudeCredentials(Data("{\"mcpOAuth\":{\"accessToken\":\"wrong\"}}".utf8)) }
rejects { _ = try UsageParser.claudeCredentials(Data("{\"claudeAiOauth\":{\"accessToken\":\"expired\",\"expiresAt\":1}}".utf8)) }
rejects { _ = try UsageParser.claudeCredentials(Data("{\"claudeAiOauth\":{\"accessToken\":\"fake\",\"scopes\":[\"user:inference\"]}}".utf8)) }
rejects { _ = try UsageParser.claudeCredentials(Data("{\"claudeAiOauth\":{\"accessToken\":\"fake\\nheader\"}}".utf8)) }

let process = try PipeProcess(path: "/bin/echo", arguments: ["{\"id\":1,\"result\":{\"ok\":true}}\n{\"id\":2,\"result\":{\"ok\":false}}"])
let framed = try process.response(id: 2)
assert(framed["ok"] as? Bool == false)
let empty = try PipeProcess(path: "/usr/bin/true", arguments: [])
rejects { _ = try empty.response(id: 1) }
let slow = try PipeProcess(path: "/bin/sleep", arguments: ["5"], timeout: 0.1)
let start = Date()
rejects { _ = try slow.readAll() }
assert(Date().timeIntervalSince(start) < 1)
print("PASS: yüzdeler, iki sağlayıcı, eksik veri, zaman damgaları, kimlik bilgileri ve süreç yanıtları.")

// Reproduce offscreen expansion and cover monitors on either side of the main display.
for visible in [CGRect(x: 0, y: 25, width: 1440, height: 850),
                CGRect(x: -1920, y: 25, width: 1920, height: 1050),
                CGRect(x: 1440, y: -900, width: 1280, height: 875)] {
    for original in [CGRect(x: visible.maxX - 50, y: visible.maxY - 200, width: 370, height: 560),
                     CGRect(x: visible.minX - 100, y: visible.minY - 300, width: 370, height: 560),
                     CGRect(x: visible.minX + 100, y: visible.minY + 50, width: 370, height: 1800)] {
        assert(visible.contains(PanelPlacement.fit(original, inside: visible)))
    }
    let valid = CGRect(x: visible.minX + 100, y: visible.minY + 100, width: 370, height: 400)
    assert(PanelPlacement.fit(valid, inside: visible) == valid)
}
print("PASS: panel ekran sınırları ve farklı monitör koordinatları.")

if CommandLine.arguments.contains("--live-codex") {
    let live = try Providers.codex()
    for window in live.windows { print("Codex \(window.title): \(window.percentText) kaldı") }
}
