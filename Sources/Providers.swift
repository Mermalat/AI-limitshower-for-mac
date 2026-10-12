// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Mermalat

import Foundation
import Darwin

// One short-lived process per refresh; no inference or conversation is started.
final class PipeProcess {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var buffer = Data()
    private let deadline: Date
    private var eof = false

    init(path: String, arguments: [String], timeout: TimeInterval = 25) throws {
        deadline = Date().addingTimeInterval(timeout)
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        process.environment = environment
        do { try process.run() }
        catch { throw UsageError.formatted("%@ başlatılamadı.", URL(fileURLWithPath: path).lastPathComponent) }
        // Close the parent's write end so a child exit produces EOF on stdout.
        output.fileHandleForWriting.closeFile()
        input.fileHandleForReading.closeFile()
    }

    deinit {
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        input.fileHandleForWriting.closeFile()
        output.fileHandleForReading.closeFile()
    }

    func send(_ message: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(10)
        try input.fileHandleForWriting.write(contentsOf: data)
    }

    private func readChunk() throws -> Data {
        while !eof {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { throw UsageError.message("Bağlantı zaman aşımına uğradı. Tekrar dene.") }
            var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, Int32(min(remaining * 1000, 1000)))
            if ready < 0 {
                if errno == EINTR { continue }
                throw UsageError.message("Yerel uygulamayla bağlantı kurulamadı.")
            }
            if ready == 0 { continue }
            var bytes = [UInt8](repeating: 0, count: 8192)
            let count = Darwin.read(descriptor.fd, &bytes, bytes.count)
            if count > 0 { return Data(bytes.prefix(count)) }
            if count < 0 && errno == EINTR { continue }
            eof = true
        }
        return Data()
    }

    func response(id: Int) throws -> [String: Any] {
        while true {
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                let response = try UsageParser.object(line)
                guard (response["id"] as? Int) == id else { continue }
                guard let result = response["result"] as? [String: Any] else {
                    throw UsageError.message("Codex limitleri okunamadı. Terminal’de codex login ile oturumunu kontrol et.")
                }
                return result
            }
            let chunk = try readChunk()
            guard !chunk.isEmpty else { throw UsageError.message("Codex bağlantısı kapandı. Codex kurulumunu ve oturumunu kontrol et.") }
            buffer.append(chunk)
            guard buffer.count < 1_048_576 else { throw UsageError.message("Yerel uygulamadan beklenmeyen yanıt geldi.") }
        }
    }

    func readAll() throws -> Data {
        var data = Data()
        while true {
            let chunk = try readChunk()
            if chunk.isEmpty { break }
            data.append(chunk)
            guard data.count < 1_048_576 else { throw UsageError.message("Yerel uygulamadan beklenmeyen yanıt geldi.") }
        }
        return data
    }
}

enum Providers {
    static func codexPath() -> String? {
        let candidates = ["/opt/homebrew/bin/codex", "/usr/local/bin/codex",
                          NSHomeDirectory() + "/.local/bin/codex", "/Applications/Codex.app/Contents/Resources/codex",
                          "/Applications/ChatGPT.app/Contents/Resources/codex"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func codex() throws -> UsageSnapshot {
        guard let path = codexPath() else { throw UsageError.message("Codex bulunamadı. Önce Codex CLI kurup ChatGPT hesabınla giriş yap.") }
        let rpc = try PipeProcess(path: path, arguments: ["app-server", "-c", "analytics.enabled=false"])
        try rpc.send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "topbar_claude_codex_limits", "version": "1.0.0"]]])
        _ = try rpc.response(id: 1)
        try rpc.send(["method": "initialized"])
        try rpc.send(["id": 2, "method": "account/rateLimits/read"])
        return try UsageParser.codex(rpc.response(id: 2))
    }

    private static func claudeCredentials() throws -> (token: String, plan: String?) {
        let config = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] ?? NSHomeDirectory() + "/.claude"
        let file = URL(fileURLWithPath: config).appendingPathComponent(".credentials.json")
        if FileManager.default.fileExists(atPath: file.path) {
            return try UsageParser.claudeCredentials(Data(contentsOf: file))
        }
        let keychain = try PipeProcess(path: "/usr/bin/security", arguments: ["find-generic-password", "-s", "Claude Code-credentials", "-w"], timeout: 15)
        let data = try keychain.readAll()
        guard !data.isEmpty else {
            throw UsageError.message("Claude Code oturumu okunamadı. Anahtar Zinciri erişimini ve Claude Code’da /login oturumunu kontrol et.")
        }
        return try UsageParser.claudeCredentials(data)
    }

    // Called only after the user explicitly enables the Claude connection.
    static func claude() async throws -> UsageSnapshot {
        let credentials = try claudeCredentials()
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer " + credentials.token, forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("TopBarClaudeCodexLimits/1.0", forHTTPHeaderField: "User-Agent")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 25
        config.httpCookieStorage = nil
        config.urlCache = nil
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw UsageError.message("Claude’a ulaşılamadı. İnternet bağlantını kontrol et.") }
        guard let http = response as? HTTPURLResponse else { throw UsageError.message("Claude’dan geçersiz yanıt geldi.") }
        switch http.statusCode {
        case 200: return try UsageParser.claude(data, plan: credentials.plan)
        case 401, 403: throw UsageError.message("Claude oturumu kabul edilmedi. Claude Code’da /login ile oturumunu yenile.")
        case 429:
            let seconds = max(300, Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 300)
            throw UsageError.rateLimited(Date().addingTimeInterval(seconds))
        default: throw UsageError.formatted("Claude geçici olarak kullanılamıyor (HTTP %@).", String(http.statusCode))
        }
    }
}

private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
