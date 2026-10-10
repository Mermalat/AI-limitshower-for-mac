// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Mermalat

import Foundation
import CoreFoundation

struct UsageWindow: Identifiable, Equatable {
    let id: String
    let title: String
    let used: Double
    let reset: Date?

    var remaining: Double { max(0, min(100, 100 - used)) }
    var percentText: String { "\(Int(remaining.rounded()))%" }
}

struct UsageSnapshot {
    let windows: [UsageWindow]
    let plan: String?
    let fetchedAt: Date

    // The menu bar shows the tightest general limit, excluding model-specific caps.
    var remaining: Double? {
        windows.filter { $0.id == "primary" || $0.id == "secondary" || $0.id == "five_hour" || $0.id == "seven_day" }
            .map(\.remaining).min()
    }
}

enum UsageError: LocalizedError {
    case message(String)
    case rateLimited(Date)
    var errorDescription: String? {
        if case .message(let text) = self { return text }
        return "Sunucu çok sık sorgulandı. Bir süre sonra otomatik tekrar denenecek."
    }
}

enum UsageParser {
    static func object(_ data: Data) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.message("Sunucudan geçersiz yanıt geldi.")
        }
        return value
    }

    static func number(_ value: Any?) -> Double? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite else { return nil }
        return n.doubleValue
    }

    static func codex(_ result: [String: Any]) throws -> UsageSnapshot {
        let buckets = result["rateLimitsByLimitId"] as? [String: Any]
        let bucket = (buckets?["codex"] as? [String: Any]) ?? (result["rateLimits"] as? [String: Any])
        guard let bucket else { throw UsageError.message("Codex limit verisi yok. ChatGPT hesabıyla Codex’e giriş yap.") }
        var windows: [UsageWindow] = []
        for key in ["primary", "secondary"] {
            guard let raw = bucket[key] as? [String: Any], let used = number(raw["usedPercent"]), used >= 0 else { continue }
            let minutes = number(raw["windowDurationMins"]).flatMap { $0 >= 0 && $0 <= 525600 ? $0 : nil }
            let title: String
            if let minutes, minutes >= 10080 { title = "Haftalık" }
            else if let minutes, minutes >= 60 { title = "\(Int(minutes / 60)) saatlik" }
            else if let minutes { title = "\(Int(minutes)) dakikalık" }
            else { title = key == "primary" ? "Kısa dönem" : "Uzun dönem" }
            windows.append(UsageWindow(id: key, title: title, used: used,
                                       reset: number(raw["resetsAt"]).map { Date(timeIntervalSince1970: $0) }))
        }
        guard !windows.isEmpty else { throw UsageError.message("Codex bu hesap için limit yüzdesi döndürmedi.") }
        return UsageSnapshot(windows: windows, plan: bucket["planType"] as? String, fetchedAt: Date())
    }

    static func claude(_ data: Data, plan: String?) throws -> UsageSnapshot {
        let raw = try object(data)
        var windows: [UsageWindow] = []
        for (key, title) in [("five_hour", "5 saatlik"), ("seven_day", "Haftalık"),
                             ("seven_day_sonnet", "Sonnet · haftalık"), ("seven_day_opus", "Opus · haftalık")] {
            guard let window = raw[key] as? [String: Any], let used = number(window["utilization"]), used >= 0 else { continue }
            let reset: Date?
            if let text = window["resets_at"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                reset = formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
            } else { reset = nil }
            // Anthropic utilization is already a percentage (0...100).
            windows.append(UsageWindow(id: key, title: title, used: used, reset: reset))
        }
        guard !windows.isEmpty else { throw UsageError.message("Claude bu hesap için limit yüzdesi döndürmedi.") }
        return UsageSnapshot(windows: windows, plan: plan, fetchedAt: Date())
    }

    static func claudeCredentials(_ data: Data) throws -> (token: String, plan: String?) {
        let raw = try object(data)
        guard let oauth = raw["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty,
              !token.contains("\n"), !token.contains("\r") else {
            throw UsageError.message("Claude Code oturumu yok. Terminal’de claude açıp /login çalıştır.")
        }
        if let expiry = number(oauth["expiresAt"]), expiry / 1000 <= Date().timeIntervalSince1970 {
            throw UsageError.message("Claude oturumu süresi doldu. Claude Code’u açarak oturumu yenile, sonra tekrar dene.")
        }
        if let scopes = oauth["scopes"] as? [String], !scopes.contains("user:profile") {
            throw UsageError.message("Claude oturumunda kullanım okuma izni yok. Claude Code’da /login ile tekrar giriş yap.")
        }
        return (token, oauth["subscriptionType"] as? String)
    }
}
