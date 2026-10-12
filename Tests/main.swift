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

// Local history fixtures contain counters only, never real conversations or credentials.
let historyRoot = FileManager.default.temporaryDirectory.appendingPathComponent("TokenHistoryTests-\(UUID())")
try FileManager.default.createDirectory(at: historyRoot, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: historyRoot) }
var historyCalendar = Calendar(identifier: .gregorian)
historyCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
let historyNow = ISO8601DateFormatter().date(from: "2026-10-12T12:00:00Z")!
func writeHistory(_ name: String, _ rows: [[String: Any]]) throws {
    let file = historyRoot.appendingPathComponent(name + ".jsonl")
    let data = try rows.reduce(into: Data()) { data, row in
        data.append(try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]))
        data.append(10)
    }
    try data.write(to: file)
    try FileManager.default.setAttributes([.modificationDate: historyNow], ofItemAtPath: file.path)
}
func codexEvent(_ date: String, _ input: Int, _ cache: Int, _ output: Int) -> [String: Any] {
    ["type": "event_msg", "timestamp": date, "payload": ["type": "token_count", "info": [
        "total_token_usage": ["input_tokens": input, "cached_input_tokens": cache, "output_tokens": output,
                              "reasoning_output_tokens": output / 2],
        "last_token_usage": ["input_tokens": input, "cached_input_tokens": cache, "output_tokens": output]]]]
}
let context: [String: Any] = ["type": "turn_context", "payload": ["model": "gpt-6.1-sol"]]
let oldCount = codexEvent("2026-10-05T12:00:00Z", 100, 50, 20)
let newCount = codexEvent("2026-10-12T10:00:00Z", 200, 100, 40)
try writeHistory("codex", [context, oldCount, newCount, newCount])
let codexHistory = TokenHistory.read(.codex, now: historyNow, roots: [historyRoot], calendar: historyCalendar)
assert(codexHistory.tokens == 120, "Cutoff baseline, cached and reasoning tokens must not be double counted")
assert(abs(codexHistory.usd - 0.000305) < 1e-10)
try writeHistory("fork", [context, oldCount, newCount])
assert(TokenHistory.read(.codex, now: historyNow, roots: [historyRoot], calendar: historyCalendar).tokens == 120)
try writeHistory("guardian", [["type": "session_meta", "payload": ["source": ["subagent": ["other": "guardian"]]]], context, newCount])
assert(TokenHistory.read(.codex, now: historyNow, roots: [historyRoot], calendar: historyCalendar).tokens == 120)
try writeHistory("reset", [context, oldCount, codexEvent("2026-10-12T11:00:00Z", 10, 5, 2)])
assert(TokenHistory.read(.codex, now: historyNow, roots: [historyRoot], calendar: historyCalendar).tokens == 132)
func claudeEvent(_ id: String, _ model: String, _ output: Int) -> [String: Any] {
    ["type": "assistant", "timestamp": "2026-10-12T10:30:00Z", "message": ["id": id, "model": model,
        "usage": ["input_tokens": 10, "cache_read_input_tokens": 100, "cache_creation_input_tokens": 40,
                  "cache_creation": ["ephemeral_1h_input_tokens": 30, "ephemeral_5m_input_tokens": 10],
                  "output_tokens": output, "output_tokens_details": ["thinking_tokens": 5]]]]
}
try writeHistory("claude", [claudeEvent("msg-1", "claude-sonnet-5-5", 10),
                             claudeEvent("msg-1", "claude-sonnet-5-5", 20),
                             claudeEvent("msg-1", "claude-sonnet-5-5", 20)])
let claudeHistory = TokenHistory.read(.claude, now: historyNow, roots: [historyRoot], calendar: historyCalendar)
assert(claudeHistory.tokens == 170)
assert(abs(claudeHistory.usd - 0.000375) < 1e-10)
try writeHistory("unknown", [claudeEvent("msg-2", "unknown-model", 20)])
let partialHistory = TokenHistory.read(.claude, now: historyNow, roots: [historyRoot], calendar: historyCalendar)
assert(partialHistory.tokens == 340 && partialHistory.unpricedTokens == 170 && partialHistory.hasPrice)
let absent = TokenHistory.read(.claude, now: historyNow, roots: [historyRoot.appendingPathComponent("absent")], calendar: historyCalendar)
assert(!absent.available)
let malformed = historyRoot.appendingPathComponent("broken.jsonl")
try Data("{\"usage\":broken}\n".utf8).write(to: malformed)
assert(TokenHistory.read(.claude, now: historyNow, roots: [historyRoot], calendar: historyCalendar).incomplete)
assert(TokenAmounts.codex(["input_tokens": true, "output_tokens": -5]).total == 0)
assert(codexHistory.days.count == 7)
assert(codexHistory.days.first?.date == ISO8601DateFormatter().date(from: "2026-10-06T00:00:00Z"))
assert(codexHistory.days.last?.tokens == 120)
assert(codexHistory.days.dropLast().allSatisfy { $0.tokens == 0 })
assert(partialHistory.days.reduce(0) { $0 + $1.tokens } == partialHistory.tokens)
assert(partialHistory.days.reduce(0) { $0 + $1.usd } == partialHistory.usd)
try writeHistory("week-boundary", [context,
    codexEvent("2026-10-05T23:59:59Z", 10, 0, 0),
    codexEvent("2026-10-06T00:00:00Z", 30, 0, 0),
    codexEvent("2026-10-07T00:00:00Z", 60, 0, 0),
    codexEvent("2026-10-12T13:00:00Z", 100, 0, 0)])
let week = TokenHistory.read(.codex, now: historyNow, roots: [historyRoot], calendar: historyCalendar)
assert(week.days[0].tokens == 20 && week.days[1].tokens == 30)
assert(week.tokens == 182, "Future events must be excluded")
var localCalendar = historyCalendar
localCalendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
let localWeek = TokenHistory.read(.codex, now: historyNow, roots: [historyRoot], calendar: localCalendar)
assert(localWeek.days[0].tokens == 30, "Local midnight must be used")
// Calendar days remain seven days across daylight-saving changes, not 168 fixed hours.
var dstCalendar = historyCalendar
dstCalendar.timeZone = TimeZone(identifier: "America/New_York")!
let dstNow = ISO8601DateFormatter().date(from: "2026-11-02T12:00:00Z")!
let dst = TokenHistory.read(.claude, now: dstNow, roots: [], calendar: dstCalendar)
assert(dst.days.count == 7)
assert(dst.days[6].date.timeIntervalSince(dst.days[0].date) == 145 * 3600)
print("PASS: seven local calendar days, daily token/USD sums, empty days, midnight/DST boundaries, duplicates and cache pricing.")
if CommandLine.arguments.contains("--live-history") {
    for (name, provider) in [("Codex", HistoryProvider.codex), ("Claude", HistoryProvider.claude)] {
        let result = TokenHistory.read(provider)
        print("\(name): tokens=\(Int(result.tokens)) USD=\(result.usd) unpriced=\(Int(result.unpricedTokens)) incomplete=\(result.incomplete)")
    }
}
