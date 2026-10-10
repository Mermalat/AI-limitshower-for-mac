// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Mermalat

import AppKit
import SwiftUI
import Darwin

@MainActor
final class UsageStore: ObservableObject {
    @Published var codex: UsageSnapshot?
    @Published var claude: UsageSnapshot?
    @Published var codexError: String?
    @Published var claudeError: String?
    @Published var codexLoading = false
    @Published var claudeLoading = false
    @Published var claudeEnabled = UserDefaults.standard.bool(forKey: "claudeEnabled")
    var onChange: (() -> Void)?
    private var timer: Timer?
    private var claudeRetryAt = Date.distantPast
    private var lastManualRefresh = Date.distantPast

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh(manual: Bool = false) {
        if manual {
            guard Date().timeIntervalSince(lastManualRefresh) >= 30 else { return }
            lastManualRefresh = Date()
        }
        if !codexLoading {
            codexLoading = true
            Task {
                do {
                    codex = try await Task.detached(priority: .utility) { try Providers.codex() }.value
                    codexError = nil
                } catch { codexError = error.localizedDescription }
                codexLoading = false
                onChange?()
            }
        }
        if claudeEnabled && !claudeLoading && Date() >= claudeRetryAt {
            claudeLoading = true
            Task {
                do {
                    let snapshot = try await Task.detached(priority: .utility) { try await Providers.claude() }.value
                    if claudeEnabled { claude = snapshot; claudeError = nil }
                } catch {
                    if claudeEnabled {
                        claudeError = error.localizedDescription
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
        UserDefaults.standard.set(true, forKey: "claudeEnabled")
        refresh()
    }

    func disableClaude() {
        claudeEnabled = false
        UserDefaults.standard.set(false, forKey: "claudeEnabled")
        claude = nil
        claudeError = nil
        onChange?()
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
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)
    }
}

struct LimitsPanel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Kullanım durumu").font(.system(size: 21, weight: .semibold))
                    Text("Codex ve Claude · kalan kota").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 25, weight: .light)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            ProviderCard(name: "Codex", accent: codexAccent, snapshot: store.codex,
                         error: store.codexError, loading: store.codexLoading,
                         usageURL: "https://chatgpt.com/codex/settings/usage")

            if store.claudeEnabled {
                ProviderCard(name: "Claude", accent: claudeAccent, snapshot: store.claude,
                             error: store.claudeError, loading: store.claudeLoading,
                             usageURL: "https://claude.ai/settings/usage")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 9) {
                        ProviderIcon(name: "Claude")
                        Text("Claude").font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text("Bağlı değil").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Text("Mevcut Claude Code oturumunla limitlerini göster. Bağlantı, oturum token’ını yalnızca Anthropic’in kullanım servisine gönderir.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Claude bağlantısını etkinleştir") { store.enableClaude() }
                        .buttonStyle(.borderedProminent).tint(claudeAccent)
                }.padding(16).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            }

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                Text("5 dakikada bir güncellenir")
                Spacer()
                Button { store.refresh(manual: true) } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.codexLoading || store.claudeLoading)
                .help("Şimdi yenile (en sık 30 saniyede bir)")
                .accessibilityLabel("Limitleri şimdi yenile")
                Menu {
                    if store.claudeEnabled {
                        Button("Claude bağlantısını kapat") { store.disableClaude() }
                        Divider()
                    }
                    Button("Çıkış") { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize()
                .accessibilityLabel("Uygulama menüsü")
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 370)
    }
}

private struct ProviderCard: View {
    let name: String
    let accent: Color
    let snapshot: UsageSnapshot?
    let error: String?
    let loading: Bool
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
                    Text(snapshot == nil ? "Bağlantı yok" : "Eski veri")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.orange)
                } else {
                    Circle().fill(accent).frame(width: 6, height: 6).accessibilityLabel("Bağlı")
                }
            }
            if let snapshot {
                ForEach(snapshot.windows) { window in
                    WindowRow(window: window, accent: accent).opacity(error == nil ? 1 : 0.5)
                }
            } else if error == nil {
                Text("Limitler okunuyor…").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if let snapshot {
                    Text("Güncellendi: \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                Spacer()
                Link(destination: URL(string: usageURL)!) {
                    Image(systemName: "arrow.up.right.square").font(.system(size: 11))
                }.foregroundStyle(.secondary).help("\(name) kullanım sayfasını aç")
                    .accessibilityLabel("\(name) kullanım sayfasını aç")
            }
        }.padding(16).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct WindowRow: View {
    let window: UsageWindow
    let accent: Color
    private var color: Color { window.remaining <= 10 ? .red : window.remaining <= 30 ? .orange : accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(window.percentText).font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundStyle(color)
                Text("kaldı").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.13))
                    Capsule().fill(color).frame(width: geometry.size.width * window.remaining / 100)
                }
            }.frame(height: 5).accessibilityHidden(true)
            if let reset = window.reset {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(reset > context.date ? "Yenilenme: \(reset.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Locale(identifier: "tr_TR"))))" : "Yenilenme zamanı geldi · güncelleme bekleniyor")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }.accessibilityElement(children: .combine)
            .help("Kullanılan: \(Int(min(100, window.used).rounded()))%")
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
        popover.animates = false
        popover.delegate = self
        store.onChange = { [weak self] in self?.updateTitle() }
        store.start()
        updateTitle()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { togglePanel(nil) }
        return true
    }

    private func updateTitle() {
        func text(_ snapshot: UsageSnapshot?, _ error: String?) -> String {
            guard let remaining = snapshot?.remaining else { return "—" }
            return "\(Int(remaining.rounded()))%" + (error == nil ? "" : "!")
        }
        for (index, provider) in [("Codex", store.codex, store.codexError),
                                   ("Claude", store.claude, store.claudeError)].enumerated() {
            let (name, snapshot, error) = provider
            let value = text(snapshot, error)
            let button = statusItems[index].button
            button?.title = " " + value
            button?.toolTip = "\(name) · kısa dönem ve haftalık limitlerden en düşük kalan yüzde. ! = eski veri."
            button?.setAccessibilityLabel("\(name) \(value) kaldı")
        }
        if popover.isShown { positionPanelOnScreen() }
    }

    @objc private func togglePanel(_ sender: NSStatusBarButton?) {
        guard let button = sender ?? statusItems.first?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            anchorButton = button
            guard let screen = button.window?.screen ?? NSScreen.main else { return }
            // Keep the window height stable while asynchronous usage data adds rows.
            let height = min(560, screen.visibleFrame.height - 48)
            popover.contentViewController = NSHostingController(rootView:
                ScrollView { LimitsPanel(store: store) }.frame(width: 370, height: height))
            popover.contentSize = NSSize(width: 370, height: height)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func popoverDidShow(_ notification: Notification) {
        positionPanelOnScreen()
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
