import Foundation

/// Debug logger that writes to /tmp/jurassicair.log. Unified logging swallows
/// NSLog from some Swift contexts on recent macOS, so this is a foolproof
/// fallback while diagnosing permission/scheduling issues.
///
/// Writes run on a private serial queue, so callers on the main thread never
/// wait for disk I/O. The file handle and the date formatter are created one
/// time and then re-used.
enum Log {
    private static let url = URL(fileURLWithPath: "/tmp/jurassicair.log")
    private static let queue = DispatchQueue(label: "jurassicair.log", qos: .utility)
    // Only touched on `queue`.
    nonisolated(unsafe) private static let formatter = ISO8601DateFormatter()
    nonisolated(unsafe) private static var handle: FileHandle?

    static func write(_ message: String, file: String = #fileID, line: Int = #line) {
        let date = Date()
        queue.async {
            let entry = "\(formatter.string(from: date)) \(file):\(line) - \(message)\n"
            guard let data = entry.data(using: .utf8), let handle = openHandle() else { return }
            do {
                try handle.write(contentsOf: data)
            } catch {
                // The file was removed or rotated. Re-open on the next write.
                try? handle.close()
                Self.handle = nil
            }
        }
    }

    private static func openHandle() -> FileHandle? {
        if let handle { return handle }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let h = try? FileHandle(forWritingTo: url) else { return nil }
        _ = try? h.seekToEnd()
        handle = h
        return h
    }
}
