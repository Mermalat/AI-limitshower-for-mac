// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Mermalat

import AppKit
import SwiftUI
import Darwin

@MainActor
final class UsageStore: ObservableObject {
    @Published var codexTokens: TokenHistorySummary?
    @Published var claudeTokens: TokenHistorySummary?
    @Published var historyLoading = false
    @Published var codex: UsageSnapshot?
    @Published var claude: UsageSnapshot?
    @Published var codexError: Error?
    @Published var claudeError: Error?
    @Published var codexLoading = false
    @Published var claudeLoading = false
    @Published private(set) var claudeEnabled: Bool
    @Published private(set) var codexVisible: Bool
    @Published private(set) var claudeVisible: Bool
    @Published private(set) var codexExpanded = false
    @Published private(set) var claudeExpanded = false
    @Published private(set) var tokensVisible: Bool
    @Published private(set) var language: AppLanguage
    private let defaults: UserDefaults
    private var codexRevision = 0
    private var claudeRevision = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        tokensVisible = defaults.object(forKey: "tokensVisible") as? Bool ?? true
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "tr") ?? .tr
        claudeEnabled = defaults.bool(forKey: "claudeEnabled")
        codexVisible = defaults.object(forKey: "codexVisible") as? Bool ?? true
        claudeVisible = defaults.object(forKey: "claudeVisible") as? Bool ?? true
        let minutes = defaults.integer(forKey: "refreshMinutes")
        refreshMinutes = (1...10).contains(minutes) ? minutes : 5
        if !codexVisible && !claudeVisible {
            codexVisible = true
            defaults.set(true, forKey: "codexVisible")
        }
    }

    func setCodexVisible(_ visible: Bool) {
        guard visible != codexVisible, visible || claudeVisible else { return }
        codexVisible = visible
        codexRevision += 1
        defaults.set(visible, forKey: "codexVisible")
        if visible { refresh() } else { codex = nil; codexError = nil; codexTokens = nil }
        onChange?()
    }

    func setClaudeVisible(_ visible: Bool) {
        guard visible != claudeVisible, visible || codexVisible else { return }
        claudeVisible = visible
        claudeRevision += 1
        defaults.set(visible, forKey: "claudeVisible")
        if visible { refresh() } else { claude = nil; claudeError = nil; claudeTokens = nil }
        onChange?()
    }
    @Published private(set) var refreshMinutes: Int
    var onChange: (() -> Void)?
    private var timer: Timer?
    private var claudeRetryAt = Date.distantPast
    private var lastManualRefresh = Date.distantPast

    func setCodexExpanded(_ expanded: Bool) {
        guard expanded != codexExpanded else { return }
        codexExpanded = expanded
        onChange?()
    }

    func setClaudeExpanded(_ expanded: Bool) {
        guard expanded != claudeExpanded else { return }
        claudeExpanded = expanded
        onChange?()
    }

    func setTokensVisible(_ visible: Bool) {
        guard visible != tokensVisible else { return }
        tokensVisible = visible
        defaults.set(visible, forKey: "tokensVisible")
        if visible { refresh() }
        onChange?()
    }

    func setLanguage(_ language: AppLanguage) {
        guard language != self.language else { return }
        self.language = language
        defaults.set(language.rawValue, forKey: "language")
        onChange?()
    }

    func start() {
        refresh()
        scheduleRefresh()
    }

    func setRefreshMinutes(_ minutes: Int) {
        guard (1...10).contains(minutes), minutes != refreshMinutes else { return }
        refreshMinutes = minutes
        defaults.set(minutes, forKey: "refreshMinutes")
        scheduleRefresh()
    }

    private func scheduleRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshMinutes * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh(manual: Bool = false) {
        if manual {
            guard Date().timeIntervalSince(lastManualRefresh) >= 30 else { return }
            lastManualRefresh = Date()
        }
        if tokensVisible && !historyLoading {
            historyLoading = true
            let codexRevision = self.codexRevision
            let claudeRevision = self.claudeRevision
            let readCodex = codexVisible
            let readClaude = claudeVisible
            Task {
                let summaries = await Task.detached(priority: .utility) {
                    (readCodex ? TokenHistory.read(.codex) : nil, readClaude ? TokenHistory.read(.claude) : nil)
                }.value
                if tokensVisible && codexVisible && codexRevision == self.codexRevision { codexTokens = summaries.0 }
                if tokensVisible && claudeVisible && claudeRevision == self.claudeRevision { claudeTokens = summaries.1 }
                historyLoading = false
                onChange?()
                if (codexVisible && codexRevision != self.codexRevision)
                    || (claudeVisible && claudeRevision != self.claudeRevision) { refresh() }
            }
        }
        if codexVisible && !codexLoading {
            codexLoading = true
            let revision = codexRevision
            Task {
                do {
                    let snapshot = try await Task.detached(priority: .utility) { try Providers.codex() }.value
                    if codexVisible && revision == codexRevision { codex = snapshot; codexError = nil }
                } catch {
                    if codexVisible && revision == codexRevision { codexError = error }
                }
                codexLoading = false
                onChange?()
            }
        }
        if claudeVisible && claudeEnabled && !claudeLoading && Date() >= claudeRetryAt {
            claudeLoading = true
            let revision = claudeRevision
            Task {
                do {
                    let snapshot = try await Task.detached(priority: .utility) { try await Providers.claude() }.value
                    if claudeVisible && revision == claudeRevision { claude = snapshot; claudeError = nil }
                } catch {
                    if claudeVisible && revision == claudeRevision {
                        claudeError = error
                        if case UsageError.rateLimited(let date) = error { claudeRetryAt = date }
                    }
                }
                claudeLoading = false
                onChange?()
            }
        }
        onChange?()
    }

    func enableClaude() {
        claudeEnabled = true
        defaults.set(true, forKey: "claudeEnabled")
        refresh()
    }

}

private let codexAccent = Color(red: 0.18, green: 0.66, blue: 0.49)
private let claudeAccent = Color(red: 0.80, green: 0.47, blue: 0.34)

private enum ProviderImages {
    static let codexLight = load("CodexLight")
    static let codexDark = load("CodexDark")
    static let claude = load("Claude")

    private static func load(_ name: String) -> NSImage {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("Paketlenmiş \(name) simgesi bulunamadı")
        }
        return image
    }
}

private struct ProviderIcon: View {
    let name: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(nsImage: name == "Codex" ? (colorScheme == .dark ? ProviderImages.codexDark : ProviderImages.codexLight) : ProviderImages.claude)
            .resizable().interpolation(.high).scaledToFit()
            .frame(width: 26, height: 26)
            .accessibilityHidden(true)
    }
}

struct LimitsPanel: View {
    @ObservedObject var store: UsageStore
    private var language: AppLanguage { store.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("Kullanım durumu", language)).font(.system(size: 21, weight: .semibold))
                    Text(L10n.text("%@ · kalan kota", language, store.codexVisible ? (store.claudeVisible ? L10n.text("Codex ve Claude", language) : "Codex") : "Claude")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 25, weight: .light)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            if store.codexVisible {
                ProviderCard(name: "Codex", expanded: store.codexExpanded, onToggle: { store.setCodexExpanded(!store.codexExpanded) }, language: language, accent: codexAccent, snapshot: store.codex,
                             error: store.codexError, loading: store.codexLoading, tokens: store.codexTokens, tokensVisible: store.tokensVisible,
                             usageURL: "https://chatgpt.com/codex/settings/usage")
            }

            if store.claudeVisible {
                if store.claudeEnabled {
                    ProviderCard(name: "Claude", expanded: store.claudeExpanded, onToggle: { store.setClaudeExpanded(!store.claudeExpanded) }, language: language, accent: claudeAccent, snapshot: store.claude,
                                 error: store.claudeError, loading: store.claudeLoading, tokens: store.claudeTokens, tokensVisible: store.tokensVisible,
                                 usageURL: "https://claude.ai/settings/usage")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 9) {
                            ProviderIcon(name: "Claude")
                            Text("Claude").font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Text(L10n.text("Bağlı değil", language)).font(.system(size: 11)).foregroundStyle(.secondary)
                            ProviderArrow(name: "Claude", expanded: store.claudeExpanded, language: language) {
                                store.setClaudeExpanded(!store.claudeExpanded)
                            }
                        }
                        if store.claudeExpanded {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(L10n.text("Mevcut Claude Code oturumunla limitlerini göster. Bağlantı, oturum token’ını yalnızca Anthropic’in kullanım servisine gönderir.", language))
                                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                if store.tokensVisible {
                                    TokenUsageView(summary: store.claudeTokens, language: language).accentColor(claudeAccent)
                                }
                                Button(L10n.text("Claude bağlantısını etkinleştir", language)) { store.enableClaude() }
                                    .buttonStyle(.borderedProminent).tint(claudeAccent)
                            }
                        }
                    }.clipped().padding(16).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                Menu {
                    Picker(L10n.text("Otomatik güncelleme", language), selection: Binding(
                        get: { store.refreshMinutes }, set: { store.setRefreshMinutes($0) })) {
                        ForEach(1...10, id: \.self) { minutes in
                            Text(L10n.text("%d dakika", language, minutes)).tag(minutes)
                        }
                    }
                } label: {
                    Text(L10n.text("%d dakikada bir güncellenir", language, store.refreshMinutes))
                }
                .menuStyle(.borderlessButton).fixedSize()
                .help(L10n.text("Otomatik güncelleme aralığını seç (1–10 dakika)", language))
                .accessibilityLabel(L10n.text("%d dakikada bir güncellenir", language, store.refreshMinutes))
                Spacer()
                Button { store.refresh(manual: true) } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled((store.codexVisible && store.codexLoading) || (store.claudeVisible && store.claudeLoading))
                .help(L10n.text("Şimdi yenile (en sık 30 saniyede bir)", language))
                .accessibilityLabel(L10n.text("Limitleri şimdi yenile", language))
                Menu {
                    Button(L10n.text(store.codexVisible ? "Codex’i kapat" : "Codex’i aç", language)) {
                        store.setCodexVisible(!store.codexVisible)
                    }.disabled(store.codexVisible && !store.claudeVisible)
                    Button(L10n.text(store.claudeVisible ? "Claude’u kapat" : "Claude’u aç", language)) {
                        store.setClaudeVisible(!store.claudeVisible)
                    }.disabled(store.claudeVisible && !store.codexVisible)
                    Text(L10n.text("En az bir sağlayıcı açık kalmalı", language))
                    Divider()
                    Button(L10n.text(store.tokensVisible ? "Token bölümünü kapat" : "Token bölümünü aç", language)) {
                        store.setTokensVisible(!store.tokensVisible)
                    }
                    Divider()
                    Picker(L10n.text("Dil", language), selection: Binding(
                        get: { store.language }, set: { store.setLanguage($0) })) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.name).tag(language)
                        }
                    }
                    Divider()
                    Button(L10n.text("Çıkış", language)) { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize()
                .accessibilityLabel(L10n.text("Uygulama menüsü", language))
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 370)
    }
}

struct PanelContent: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        ScrollView {
            LimitsPanel(store: store).fixedSize(horizontal: false, vertical: true)
        }.frame(width: 370)
            .transaction { $0.animation = nil }
    }
}

@MainActor
final class PanelController: NSHostingController<PanelContent> {
    private let store: UsageStore
    private let maximumHeight: CGFloat
    private let onResize: (NSSize) -> Void

    init(store: UsageStore, maximumHeight: CGFloat, onResize: @escaping (NSSize) -> Void) {
        self.store = store
        self.maximumHeight = maximumHeight
        self.onResize = onResize
        super.init(rootView: PanelContent(store: store))
        // AppKit owns the viewport size; SwiftUI must not retain an old minimum height.
        sizingOptions = []
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func resizeToContent() {
        let measurement = NSHostingView(rootView: LimitsPanel(store: store))
        let height = min(ceil(measurement.fittingSize.height), maximumHeight)
        onResize(NSSize(width: 370, height: max(1, height)))
    }
}

private struct ProviderArrow: View {
    let name: String
    let expanded: Bool
    let language: AppLanguage
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .rotationEffect(.degrees(expanded ? 180 : 0))
                .animation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .easeInOut(duration: 0.25), value: expanded)
                .padding(6).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(L10n.text(expanded ? "%@ ayrıntılarını kapat" : "%@ ayrıntılarını aç", language, name))
            .help(L10n.text(expanded ? "%@ ayrıntılarını kapat" : "%@ ayrıntılarını aç", language, name))
    }
}

private struct ProviderCard: View {
    let name: String
    let expanded: Bool
    let onToggle: () -> Void
    let language: AppLanguage
    let accent: Color
    let snapshot: UsageSnapshot?
    let error: Error?
    let loading: Bool
    let tokens: TokenHistorySummary?
    let tokensVisible: Bool
    let usageURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                ProviderIcon(name: name)
                Text(name).font(.system(size: 15, weight: .semibold))
                if let plan = snapshot?.plan {
                    Text(plan.capitalized).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 3).background(.quaternary, in: Capsule())
                }
                Spacer()
                if loading { ProgressView().controlSize(.small) }
                else if error != nil {
                    Text(L10n.text(snapshot == nil ? "Bağlantı yok" : "Eski veri", language))
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.orange)
                } else {
                    Circle().fill(accent).frame(width: 6, height: 6).accessibilityLabel(L10n.text("Bağlı", language))
                }
                if !expanded, let remaining = snapshot?.remaining {
                    Text("\(Int(remaining.rounded()))%")
                        .font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(accent)
                }
                ProviderArrow(name: name, expanded: expanded, language: language, onToggle: onToggle)
            }
            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    if let snapshot {
                        ForEach(snapshot.windows) { window in
                            WindowRow(window: window, language: language, accent: accent).opacity(error == nil ? 1 : 0.5)
                        }
                    } else if error == nil {
                        Text(L10n.text("Limitler okunuyor…", language)).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    if let error {
                        Label(L10n.error(error, language), systemImage: "exclamationmark.circle")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if tokensVisible {
                        Divider()
                        TokenUsageView(summary: tokens, language: language).accentColor(accent)
                    }
                    HStack {
                        if let snapshot {
                            Text(L10n.text("Güncellendi: %@", language, snapshot.fetchedAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(language.locale))))
                                .font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Link(destination: URL(string: usageURL)!) {
                            Image(systemName: "arrow.up.right.square").font(.system(size: 11))
                        }.foregroundStyle(.secondary).help(L10n.text("%@ kullanım sayfasını aç", language, name))
                            .accessibilityLabel(L10n.text("%@ kullanım sayfasını aç", language, name))
                    }
                }
            }
        }.clipped().padding(16).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct TokenUsageView: View {
    let summary: TokenHistorySummary?
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("Son 7 gün · token kullanımı", language))
                .font(.system(size: 12, weight: .medium))
            if let summary, summary.available {
                HStack {
                    Text(summary.tokens.formatted(.number.locale(language.locale).precision(.fractionLength(0))) + " tokens")
                        .monospacedDigit()
                    Spacer()
                    Text(summary.hasPrice ? summary.usd.formatted(.currency(code: "USD").locale(language.locale)) : "—")
                        .monospacedDigit().fontWeight(.semibold)
                }.font(.system(size: 13))
                Text(L10n.text("Tahmini API karşılığı · fatura değildir", language))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                DailyTokenChart(days: summary.days, language: language)
                if summary.unpricedTokens > 0 {
                    Text(L10n.text("Bazı modellerin fiyatı bilinmiyor; tutar eksik olabilir.", language))
                        .font(.system(size: 10)).foregroundStyle(.orange)
                }
                if summary.incomplete {
                    Text(L10n.text("Bazı yerel kayıtlar okunamadı; toplam eksik olabilir.", language))
                        .font(.system(size: 10)).foregroundStyle(.orange)
                }
            } else {
                Text(L10n.text(summary == nil ? "Token kullanımı hesaplanıyor…" : "Yerel kullanım kaydı bulunamadı.", language))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }.help(L10n.text("Bugün dahil son 7 gün, bu Mac’in yerel saatine göre. Standart API karşılığı; fatura değildir.", language))
    }
}

struct DailyTokenChart: View {
    let days: [DailyTokenUsage]
    let language: AppLanguage
    private var peak: Double { max(1, days.map(\.tokens).max() ?? 0) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days) { day in
                    VStack(spacing: 5) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.08))
                            RoundedRectangle(cornerRadius: 4).fill(Color.accentColor)
                                .frame(height: 90 * day.tokens / peak)
                        }.frame(height: 90)
                        Text(day.date.formatted(Date.FormatStyle().day().month(.twoDigits).locale(language.locale)))
                            .font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
                    }.frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(detail(day))
                        .help(detail(day))
                }
            }.padding(.top, 6)
            HStack {
                Text(L10n.text("Tarih", language)).frame(maxWidth: .infinity, alignment: .leading)
                Text("Tokens").frame(maxWidth: .infinity, alignment: .trailing)
                Text("USD").frame(width: 75, alignment: .trailing)
            }.foregroundStyle(.secondary)
            ForEach(days) { day in
                HStack {
                    Text(day.date.formatted(Date.FormatStyle().day().month(.abbreviated).locale(language.locale)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(day.tokens.formatted(.number.locale(language.locale).precision(.fractionLength(0))))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(cost(day)).frame(width: 75, alignment: .trailing)
                }.monospacedDigit()
            }
        }.font(.system(size: 10))
    }

    private func cost(_ day: DailyTokenUsage) -> String {
        guard day.hasPrice else { return "—" }
        return (day.unpricedTokens > 0 ? "≥ " : "")
            + day.usd.formatted(.currency(code: "USD").locale(language.locale))
    }

    private func detail(_ day: DailyTokenUsage) -> String {
        day.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(language.locale))
            + " · " + day.tokens.formatted(.number.locale(language.locale).precision(.fractionLength(0)))
            + " tokens · " + cost(day)
    }
}

private struct WindowRow: View {
    let window: UsageWindow
    let language: AppLanguage
    let accent: Color
    private var color: Color { window.remaining <= 10 ? .red : window.remaining <= 30 ? .orange : accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.windowTitle(window.title, language)).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(window.percentText).font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundStyle(color)
                Text(L10n.text("kaldı", language)).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.13))
                    Capsule().fill(color).frame(width: geometry.size.width * window.remaining / 100)
                }
            }.frame(height: 5).accessibilityHidden(true)
            if let reset = window.reset {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(reset > context.date ? L10n.text("Yenilenme: %@", language, reset.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(language.locale))) : L10n.text("Yenilenme zamanı geldi · güncelleme bekleniyor", language))
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }.accessibilityElement(children: .combine)
            .help(L10n.text("Kullanılan: %d%%", language, Int(min(100, window.used).rounded())))
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItems: [NSStatusItem] = []
    private weak var anchorButton: NSStatusBarButton?
    private let popover = NSPopover()
    private let store = UsageStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent two menu items when the same app is opened twice.
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.mermalat.TopBarClaudeCodexLimits").count > 1 {
            NSApp.terminate(nil)
            return
        }
        for (name, image) in [("Codex", ProviderImages.codexLight), ("Claude", ProviderImages.claude)] {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.autosaveName = name
            item.isVisible = true
            if let button = item.button {
                let icon = image.copy() as! NSImage
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = name == "Codex"
                button.image = icon
                button.imagePosition = .imageLeading
                button.imageScaling = .scaleProportionallyDown
                button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
                button.target = self
                button.action = #selector(togglePanel(_:))
            }
            statusItems.append(item)
        }
        popover.behavior = .transient
        // Animated viewport resizing conflicts with SwiftUI layout and can overlay card contents.
        popover.animates = false
        popover.delegate = self
        store.onChange = { [weak self] in self?.updateTitle() }
        store.start()
        updateTitle()
        togglePanel(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { togglePanel(nil) }
        return true
    }

    private func updateTitle() {
        func text(_ snapshot: UsageSnapshot?, _ error: Error?) -> String {
            guard let remaining = snapshot?.remaining else { return "—" }
            return "\(Int(remaining.rounded()))%" + (error == nil ? "" : "!")
        }
        let visibility = [store.codexVisible, store.claudeVisible]
        if popover.isShown, let anchorButton,
           let index = statusItems.firstIndex(where: { $0.button === anchorButton }), !visibility[index] {
            self.anchorButton = statusItems[visibility.firstIndex(of: true)!].button
            if let button = self.anchorButton {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
        for (index, provider) in [("Codex", store.codex, store.codexError),
                                   ("Claude", store.claude, store.claudeError)].enumerated() {
            let (name, snapshot, error) = provider
            let value = text(snapshot, error)
            statusItems[index].isVisible = visibility[index]
            let button = statusItems[index].button
            button?.title = " " + value
            button?.toolTip = L10n.text("%@ · kısa dönem ve haftalık limitlerden en düşük kalan yüzde. ! = eski veri.", store.language, name)
            button?.setAccessibilityLabel(L10n.text("%@ %@ kaldı", store.language, name, value))
        }
        if popover.isShown {
            (popover.contentViewController as? PanelController)?.resizeToContent()
            positionPanelOnScreen()
        }
    }

    @objc private func togglePanel(_ sender: NSStatusBarButton?) {
        guard let button = sender ?? statusItems.first(where: { $0.isVisible })?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            anchorButton = button
            guard let screen = button.window?.screen ?? NSScreen.main else { return }
            let maximum = screen.visibleFrame.height - 48
            let controller = PanelController(store: store, maximumHeight: maximum) { [weak self] size in
                self?.resizePanel(to: size)
            }
            popover.contentViewController = controller
            controller.resizeToContent()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func popoverDidShow(_ notification: Notification) {
        positionPanelOnScreen()
    }

    private func resizePanel(to size: NSSize) {
        guard popover.contentSize != size else { return }
        popover.contentSize = size
    }

    private func positionPanelOnScreen() {
        guard let window = popover.contentViewController?.view.window,
              let button = anchorButton, let statusWindow = button.window,
              let screen = statusWindow.screen ?? NSScreen.main else { return }
        let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        var frame = window.frame
        frame.origin.x = anchor.maxY >= screen.visibleFrame.maxY
            ? anchor.midX - frame.width / 2
            : screen.visibleFrame.maxX - frame.width - 8
        frame.origin.y = screen.visibleFrame.maxY - frame.height - 8
        window.setFrame(PanelPlacement.fit(frame, inside: screen.visibleFrame), display: true)
        if ProcessInfo.processInfo.environment["TOPBAR_VERIFY_PLACEMENT"] == "1" {
            precondition(screen.visibleFrame.contains(window.frame), "Panel ekran dışında kaldı")
            print("PANEL_OK frame=\(window.frame) visible=\(screen.visibleFrame) anchor=\(anchor)")
            fflush(stdout)
        }
    }
}

#if !TESTING
@main
enum TopBarApp {
    static func main() {
        signal(SIGPIPE, SIG_IGN)
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

#endif
