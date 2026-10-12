// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Mermalat

import Foundation
import AppKit
import SwiftUI

@main
struct StoreTests {
    @MainActor static func main() {
        let name = "TopBarStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = UsageStore(defaults: defaults)
        assert(store.codexVisible && store.claudeVisible)
        assert(!store.claudeEnabled)
        assert(!store.codexExpanded && !store.claudeExpanded)
        store.setCodexExpanded(true)
        assert(store.codexExpanded && !store.claudeExpanded)
        store.setClaudeExpanded(true)
        assert(store.codexExpanded && store.claudeExpanded)
        assert(store.tokensVisible)
        store.setTokensVisible(false)
        assert(!UsageStore(defaults: defaults).tokensVisible)
        store.codexLoading = true
        store.claudeLoading = true
        store.refresh()
        assert(!store.historyLoading, "Kapalı token bölümünde günlükler taranmamalı")
        store.historyLoading = true
        store.setTokensVisible(true)
        assert(UsageStore(defaults: defaults).tokensVisible)
        store.codexLoading = true
        store.claudeLoading = true
        store.setCodexVisible(false)
        assert(!store.codexVisible && store.claudeVisible)
        store.setClaudeVisible(false)
        assert(store.claudeVisible, "Son sağlayıcı kapatılamamalı")
        let reopened = UsageStore(defaults: defaults)
        assert(!reopened.codexVisible && reopened.claudeVisible)
        store.codexLoading = false
        store.refresh()
        assert(!store.codexLoading, "Kapalı Codex sorgulanmamalı")
        store.codexLoading = true
        store.setCodexVisible(true)
        store.setClaudeVisible(false)
        assert(store.codexVisible && !store.claudeVisible)
        store.setCodexVisible(false)
        assert(store.codexVisible, "Son sağlayıcı kapatılamamalı")
        store.claudeLoading = false
        store.refresh()
        assert(!store.claudeLoading, "Kapalı Claude sorgulanmamalı")
        store.claudeLoading = true
        store.setClaudeVisible(true)
        assert(!store.claudeEnabled, "Göstergeyi açmak bağlantı izni vermemeli")
        store.enableClaude()
        store.setClaudeVisible(false)
        store.setClaudeVisible(true)
        assert(store.claudeEnabled, "Mevcut bağlantı tercihi korunmalı")
        defaults.set(false, forKey: "codexVisible")
        defaults.set(false, forKey: "claudeVisible")
        let repaired = UsageStore(defaults: defaults)
        assert(repaired.codexVisible && !repaired.claudeVisible)
        assert(defaults.bool(forKey: "codexVisible"))
        for minutes in 1...10 {
            store.setRefreshMinutes(minutes)
            assert(UsageStore(defaults: defaults).refreshMinutes == minutes)
        }
        store.setRefreshMinutes(0)
        store.setRefreshMinutes(11)
        assert(store.refreshMinutes == 10)
        for language in AppLanguage.allCases {
            store.setLanguage(language)
            assert(UsageStore(defaults: defaults).language == language)
            assert(!L10n.text("Kullanım durumu", language).isEmpty)
            assert(!L10n.windowTitle("5 saatlik", language).contains("%d"))
            assert(!L10n.windowTitle("Sonnet · haftalık", language).contains("%@"))
            assert(!L10n.error(UsageError.formatted("Claude geçici olarak kullanılamıyor (HTTP %@).", "500"), language).contains("%@"))
        }
        for (key, translations) in L10n.translations {
            assert(translations.count == AppLanguage.allCases.count - 1)
            func placeholders(_ text: String) -> [String] {
                let regex = try! NSRegularExpression(pattern: "%[@d%]")
                return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                    .map { String(text[Range($0.range, in: text)!]) }
            }
            for translation in translations {
                assert(!translation.isEmpty)
                assert(placeholders(key) == placeholders(translation), "Çeviri biçimi bozuk: \(key)")
            }
        }
        defaults.set("unknown", forKey: "language")
        assert(UsageStore(defaults: defaults).language == .tr)
        store.setLanguage(.tr)
        store.setCodexVisible(true)
        store.setClaudeVisible(true)
        let sample = UsageSnapshot(windows: [
            UsageWindow(id: "primary", title: "5 saatlik", used: 15, reset: Date()),
            UsageWindow(id: "secondary", title: "Haftalık", used: 30, reset: Date())
        ], plan: "Pro", fetchedAt: Date())
        store.codex = sample
        store.claude = sample
        func contentHeight() -> CGFloat {
            let view = NSHostingView(rootView: LimitsPanel(store: store))
            return view.fittingSize.height
        }
        let bothHeight = contentHeight()
        store.setCodexExpanded(false)
        assert(contentHeight() < bothHeight, "Kapalı kart kompakt olmalı")
        assert(store.claudeExpanded, "Diğer kartın açık durumu değişmemeli")
        store.setCodexExpanded(true)
        assert(contentHeight() == bothHeight, "Açılan kartın ayrıntıları geri gelmeli")
        store.setClaudeVisible(false)
        let singleHeight = contentHeight()
        assert(singleHeight > 0 && singleHeight < bothHeight, "Tek sağlayıcı içeriği küçülmeli")
        store.setClaudeVisible(true)
        store.claude = sample
        assert(contentHeight() == bothHeight, "İkinci sağlayıcı açıldığında içerik büyümeli")
        for language in AppLanguage.allCases {
            store.setLanguage(language)
            assert(contentHeight() > 0)
        }
        store.setLanguage(.tr)
        store.codex = sample
        store.claude = sample
        let panelWindow = NSWindow(contentRect: CGRect(x: -10000, y: -10000, width: 370, height: 560),
                                   styleMask: [.borderless], backing: .buffered, defer: false)
        let panelController = PanelController(store: store, maximumHeight: 760) { size in
            panelWindow.setContentSize(size)
        }
        panelWindow.contentViewController = panelController
        store.onChange = { panelController.resizeToContent() }
        panelController.resizeToContent()
        func settleLayout() {
            let deadline = Date().addingTimeInterval(0.3)
            while Date() < deadline {
                panelWindow.contentView?.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }
        }
        settleLayout()
        let expandedFrame = panelWindow.frame
        store.setCodexExpanded(false)
        settleLayout()
        assert(panelWindow.frame.height < expandedFrame.height, "Kart kapatıldığında gerçek pencere küçülmeli")
        store.setCodexExpanded(true)
        settleLayout()
        assert(abs(panelWindow.frame.height - expandedFrame.height) < 2, "Kart açıldığında gerçek pencere büyümeli")
        // Rapid expansion changes must use the current layout immediately, without stale viewport sizes.
        for index in 0..<10 {
            store.setCodexExpanded(index % 2 == 0)
            panelWindow.contentView?.layoutSubtreeIfNeeded()
            let expected = min(ceil(contentHeight()), 760)
            assert(abs(panelWindow.frame.height - expected) < 2, "Eski kart boyutu yeni içerikle karışmamalı")
        }
        store.setCodexExpanded(true)
        settleLayout()
        print("PASS: hızlı kart geçişlerinde pencere ve içerik boyutları aynı.")
        let fullFrame = panelWindow.frame
        store.setClaudeVisible(false)
        settleLayout()
        assert(panelWindow.frame.height < fullFrame.height, "Aynı pencere tek sağlayıcıya geçince küçülmeli")
        store.setClaudeVisible(true)
        store.claude = sample
        settleLayout()
        panelController.resizeToContent()
        assert(abs(panelWindow.frame.height - fullFrame.height) < 2, "Aynı pencere yeniden büyümeli")
        let smallController = PanelController(store: store, maximumHeight: 250) { size in
            assert(size.height == 250, "Uzun içerik ekran sınırında kalmalı")
        }
        smallController.resizeToContent()
        print("PASS: gerçek pencere küçülme/büyüme ve ekran yüksekliği sınırı.")
        store.onChange = nil
        panelWindow.close()
        let today = Calendar.current.startOfDay(for: Date())
        let chartDays = (0..<7).map { index in
            DailyTokenUsage(date: Calendar.current.date(byAdding: .day, value: index - 6, to: today)!,
                            tokens: Double([0, 2500, 15000, 5000, 30000, 10000, 20000][index]),
                            usd: Double(index) * 0.45)
        }
        let chartSummary = TokenHistorySummary(days: chartDays,
            tokens: chartDays.reduce(0) { $0 + $1.tokens }, usd: chartDays.reduce(0) { $0 + $1.usd }, records: 6)
        store.codexTokens = chartSummary
        store.claudeTokens = chartSummary
        for language in AppLanguage.allCases {
            store.setLanguage(language)
            let view = NSHostingView(rootView: LimitsPanel(store: store))
            assert(view.fittingSize.height > bothHeight, "Grafik ve günlük tablo panel içeriğinde görünmeli")
            assert(view.fittingSize.width == 370, "Grafik panel genişliğini aşmamalı")
        }
        let withTokens = contentHeight()
        store.setTokensVisible(false)
        let withoutTokens = contentHeight()
        assert(withoutTokens < withTokens, "Token bölümü kapatılınca panel küçülmeli")
        store.setTokensVisible(true)
        assert(contentHeight() == withTokens, "Token bölümü yeniden gösterilmeli")
        print("PASS: token bölümü açma/kapatma, kalıcı tercih, tarama durdurma ve panel boyutu.")
        print("PASS: yedi dilde haftalık grafik, günlük tablo ve panel genişliği.")
        print("PASS: tek/çift sağlayıcı yüksekliği ve yedi dilde içerik ölçümü.")
        print("PASS: yedi dil, çeviri biçimleri, dinamik başlıklar ve kalıcı dil tercihi.")
        print("PASS: tek sağlayıcı, son sağlayıcı koruması, kapalı sorgular, kalıcı seçimler ve güncelleme aralığı.")
    }
}
