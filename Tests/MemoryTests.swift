// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import Darwin

func residentBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    precondition(result == KERN_SUCCESS)
    return info.resident_size
}

@main
struct MemoryTests {
    static func main() throws {
        if CommandLine.arguments.contains("--real") {
            let initial = residentBytes()
            for _ in 0..<2 {
                autoreleasepool {
                    _ = TokenHistory.read(.codex)
                    _ = TokenHistory.read(.claude)
                }
            }
            print("Local history: before=\(initial / 1048576) MiB, after=\(residentBytes() / 1048576) MiB")
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        let now = Date()
        let timestamp = ISO8601DateFormatter().string(from: now.addingTimeInterval(-1))
        let line = "{\"type\":\"event_msg\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":100,\"cached_input_tokens\":20,\"output_tokens\":10}},\"unused\":\"\(String(repeating: "x", count: 300))\"}}\n"
        let data = Data(line.utf8)
        FileManager.default.createFile(atPath: file.path, contents: nil)
        let handle = try FileHandle(forWritingTo: file)
        let stress = CommandLine.arguments.contains("--stress")
        for _ in 0..<(stress ? 200_000 : 50_000) { try handle.write(contentsOf: data) }
        try handle.close()
        let initial = residentBytes()
        var peak = initial
        for _ in 0..<(stress ? 3 : 1) {
            autoreleasepool {
                let summary = TokenHistory.read(.codex, now: now, roots: [directory])
                precondition(summary.tokens == 110 && summary.records == 1, "Counters changed")
                peak = max(peak, residentBytes())
            }
        }
        let growth = peak - initial
        print("History scan: initial=\(initial / 1048576) MiB, peak=\(peak / 1048576) MiB, growth=\(growth / 1048576) MiB")
        fflush(stdout)
        precondition(growth < 32 * 1048576, "History scan grew more than 32 MiB")
    }
}
