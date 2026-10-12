// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Mermalat

import Foundation

enum HistoryProvider { case codex, claude }

struct TokenAmounts: Equatable {
    var input = 0.0
    var cached = 0.0
    var write5m = 0.0
    var write1h = 0.0
    var output = 0.0
    var total: Double { input + cached + write5m + write1h + output }

    static func number(_ raw: [String: Any], _ key: String) -> Double {
        guard let value = UsageParser.number(raw[key]), value >= 0, value <= 1e15 else { return 0 }
        return value
    }

    static func codex(_ raw: [String: Any]) -> TokenAmounts {
        let input = number(raw, "input_tokens")
        let cached = min(input, number(raw, "cached_input_tokens"))
        let writes = min(input - cached, number(raw, "cache_write_input_tokens"))
        // Reasoning tokens are already included in output_tokens.
        return TokenAmounts(input: input - cached - writes, cached: cached, write5m: writes,
                            output: number(raw, "output_tokens"))
    }

    static func claude(_ raw: [String: Any]) -> TokenAmounts {
        let writes = number(raw, "cache_creation_input_tokens")
        let details = raw["cache_creation"] as? [String: Any] ?? [:]
        let hour = min(writes, number(details, "ephemeral_1h_input_tokens"))
        return TokenAmounts(input: number(raw, "input_tokens"), cached: number(raw, "cache_read_input_tokens"),
                            write5m: writes - hour, write1h: hour, output: number(raw, "output_tokens"))
    }

    func delta(from previous: TokenAmounts) -> TokenAmounts {
        TokenAmounts(input: max(0, input - previous.input), cached: max(0, cached - previous.cached),
                     write5m: max(0, write5m - previous.write5m), write1h: max(0, write1h - previous.write1h),
                     output: max(0, output - previous.output))
    }

    func merging(_ other: TokenAmounts) -> TokenAmounts {
        TokenAmounts(input: max(input, other.input), cached: max(cached, other.cached),
                     write5m: max(write5m, other.write5m), write1h: max(write1h, other.write1h), output: max(output, other.output))
    }
}

struct DailyTokenUsage: Identifiable {
    let date: Date
    var tokens = 0.0
    var usd = 0.0
    var unpricedTokens = 0.0
    var id: Date { date }
    var hasPrice: Bool { tokens == 0 || unpricedTokens < tokens }
}

struct TokenHistorySummary {
    var days: [DailyTokenUsage] = []
    var tokens = 0.0
    var usd = 0.0
    var unpricedTokens = 0.0
    var incomplete = false
    var records = 0
    var available = true
    var hasPrice: Bool { records == 0 || unpricedTokens < tokens }
}

struct TokenPrice {
    let input: Double
    let cached: Double
    let output: Double
    var write5m: Double { input * 1.25 }
    var write1h: Double { input * 2 }

    func cost(_ amount: TokenAmounts) -> Double {
        (amount.input * input + amount.cached * cached + amount.output * output
         + amount.write5m * write5m + amount.write1h * write1h) / 1_000_000
    }

    // Standard API-equivalent rates per million tokens, checked 2026-10-12.
    // Sources and exclusions are documented in docs/TOKEN_USAGE.md.
    static func forModel(_ model: String) -> TokenPrice? {
        let rates: [(String, Double, Double, Double)] = [
            ("gpt-6.1-sol", 2, 0.1, 10), ("gpt-6-astra", 10, 1, 50),
            ("gpt-6-luna", 0.1, 0.01, 0.5), ("gpt-5.6-sol", 4, 0.4, 20),
            ("claude-opus-5-5", 4, 0.2, 20), ("claude-sonnet-5-5", 2, 0.1, 10),
            ("claude-sonnet-5", 2, 0.2, 10), ("claude-opus-5", 5, 0.5, 25),
            ("claude-opus-4-8", 5, 0.5, 25), ("claude-opus-4-7", 5, 0.5, 25),
            ("claude-opus-4-6", 5, 0.5, 25), ("claude-opus-4-5", 5, 0.5, 25),
            ("claude-sonnet-4-6", 3, 0.3, 15), ("claude-sonnet-4-5", 3, 0.3, 15),
            ("claude-haiku-4-5", 1, 0.1, 5)
        ]
        guard let rate = rates.first(where: { model == $0.0 || model.hasPrefix($0.0 + "-20") }) else { return nil }
        return TokenPrice(input: rate.1, cached: rate.2, output: rate.3)
    }
}

enum TokenHistory {
    static func read(_ provider: HistoryProvider, now: Date = Date(), roots: [URL]? = nil, calendar: Calendar = .current) -> TokenHistorySummary {
        let environment = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let roots = roots ?? (provider == .codex
            ? [URL(fileURLWithPath: (environment["CODEX_HOME"] ?? home + "/.codex") + "/sessions"),
               URL(fileURLWithPath: (environment["CODEX_HOME"] ?? home + "/.codex") + "/archived_sessions")]
            : [URL(fileURLWithPath: (environment["CLAUDE_CONFIG_DIR"] ?? home + "/.claude") + "/projects")])
        let today = calendar.startOfDay(for: now)
        let cutoff = calendar.date(byAdding: .day, value: -6, to: today)!
        var summary = TokenHistorySummary()
        summary.days = (0..<7).map {
            DailyTokenUsage(date: calendar.date(byAdding: .day, value: $0, to: cutoff)!)
        }
        summary.available = roots.contains { FileManager.default.fileExists(atPath: $0.path) }
        var records: [String: (String, TokenAmounts, Date)] = [:]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let secondsFormatter = ISO8601DateFormatter()
        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys:
                [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles], errorHandler: { _, _ in summary.incomplete = true; return true }) else {
                summary.incomplete = true; continue
            }
            for case let file as URL in files where file.pathExtension == "jsonl" {
                guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey]),
                      values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                if let modified = values.contentModificationDate, modified < cutoff { continue }
                var model = ""
                var previous = TokenAmounts()
                var skipSession = false
                do {
                    try lines(file) { line in
                        guard line.contains("token_count") || line.contains("session_meta") || line.contains("turn_context") || (provider == .claude && line.contains("\"usage\"")) else { return }
                        guard let data = line.data(using: .utf8), let raw = try? UsageParser.object(data) else {
                            summary.incomplete = true; return
                        }
                        if provider == .codex {
                            let payload = raw["payload"] as? [String: Any] ?? [:]
                            if raw["type"] as? String == "session_meta",
                               let source = payload["source"] as? [String: Any],
                               let subagent = source["subagent"] as? [String: Any], subagent["other"] as? String == "guardian" { skipSession = true }
                            if raw["type"] as? String == "turn_context" { model = payload["model"] as? String ?? "" }
                            guard !skipSession, model != "codex-auto-review", payload["type"] as? String == "token_count",
                                  let info = payload["info"] as? [String: Any],
                                  let total = info["total_token_usage"] as? [String: Any] else { return }
                            let current = TokenAmounts.codex(total)
                            let amount = current.total < previous.total
                                ? TokenAmounts.codex(info["last_token_usage"] as? [String: Any] ?? total)
                                : current.delta(from: previous)
                            previous = current // Also establish the baseline for events outside the weekly window.
                            guard let timestamp = raw["timestamp"] as? String,
                                  let date = formatter.date(from: timestamp) ?? secondsFormatter.date(from: timestamp),
                                  date >= cutoff, date <= now, amount.total > 0 else { return }
                            // Forked histories and repeated notifications retain timestamp and cumulative usage.
                            let key = "\(timestamp)|\(model)|\(current)"
                            records[key] = (model, amount, date)
                        } else {
                            guard raw["type"] as? String == "assistant", let message = raw["message"] as? [String: Any],
                                  let usage = message["usage"] as? [String: Any],
                                  let id = message["id"] as? String ?? raw["uuid"] as? String,
                                  let timestamp = raw["timestamp"] as? String,
                                  let date = formatter.date(from: timestamp) ?? secondsFormatter.date(from: timestamp),
                                  date >= cutoff, date <= now else { return }
                            let model = message["model"] as? String ?? ""
                            guard model != "<synthetic>" else { return }
                            let amount = TokenAmounts.claude(usage)
                            let key = model + "|" + id
                            // Preserve the first timestamp when a message is streamed across midnight.
                            let firstDate = records[key].map { min($0.2, date) } ?? date
                            records[key] = (model, records[key]?.1.merging(amount) ?? amount, firstDate)
                        }
                    }
                } catch { summary.incomplete = true }
            }
        }
        for (model, amount, date) in records.values {
            let day = calendar.startOfDay(for: date)
            guard let index = summary.days.firstIndex(where: { $0.date == day }) else { continue }
            summary.days[index].tokens += amount.total
            summary.records += 1
            if let price = TokenPrice.forModel(model) { summary.days[index].usd += price.cost(amount) }
            else { summary.days[index].unpricedTokens += amount.total }
        }
        summary.tokens = summary.days.reduce(0) { $0 + $1.tokens }
        summary.usd = summary.days.reduce(0) { $0 + $1.usd }
        summary.unpricedTokens = summary.days.reduce(0) { $0 + $1.unpricedTokens }
        return summary
    }

    // Stream logs without retaining conversation contents or entire files in memory.
    private static func lines(_ url: URL, consume: (String) -> Void) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var pending = Data()
        while let chunk = try handle.read(upToCount: 65536), !chunk.isEmpty {
            pending.append(chunk)
            while let end = pending.firstIndex(of: 10) {
                let line = pending.prefix(upTo: end)
                if let text = String(data: line, encoding: .utf8) { consume(text) }
                pending.removeSubrange(...end)
            }
            guard pending.count < 16_777_216 else { throw UsageError.message("Yerel uygulamadan beklenmeyen yanıt geldi.") }
        }
        // A trailing line can be an in-progress write; wait for its newline on the next refresh.
    }
}
