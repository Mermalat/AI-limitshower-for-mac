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
        print("PASS: tek/çift sağlayıcı yüksekliği ve yedi dilde içerik ölçümü.")
        print("PASS: yedi dil, çeviri biçimleri, dinamik başlıklar ve kalıcı dil tercihi.")
        print("PASS: tek sağlayıcı, son sağlayıcı koruması, kapalı sorgular, kalıcı seçimler ve güncelleme aralığı.")
    }
}
