import Foundation

/// Opt-in diagnostics sink. AgentBar's biggest external dependency is the exact shape of
/// Claude Code's hook payloads — especially `Elicitation`, whose field layout is not pinned
/// in the public docs. When something parses to less than expected (e.g. an elicitation
/// degrades to message-only), there is normally nothing to look at because the app is
/// notify-only and silent by design.
///
/// When the user enables "Log raw hook payloads" in Settings (or sets `AGENTBAR_DEBUG=1` in
/// the environment the app launched from), `DebugLog` appends timestamped entries — and, for
/// hook events, the raw JSON body — to `~/Library/Application Support/AgentBar/debug.log`, so
/// payload-shape drift becomes diagnosable instead of silently swallowed. The file is
/// capped so it can never grow without bound.
enum DebugLog {
    /// Cap the log at ~256 KiB; when exceeded it is truncated to the most recent half.
    private static let maxBytes = 256 * 1024

    private static let queue = DispatchQueue(label: "com.jreed91.AgentBar.debuglog")

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    /// True when logging is on: either the `debugLogging` default or the `AGENTBAR_DEBUG`
    /// environment variable. Checked per call so toggling Settings takes effect immediately.
    static var isEnabled: Bool {
        if UserDefaults.standard.bool(forKey: "debugLogging") { return true }
        if let env = ProcessInfo.processInfo.environment["AGENTBAR_DEBUG"], env == "1" || env == "true" {
            return true
        }
        return false
    }

    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AgentBar/debug.log", isDirectory: false)
    }

    /// Appends one line. A no-op unless logging is enabled, so call sites need no guard.
    static func log(_ message: String) {
        guard isEnabled else { return }
        write("[\(stamp.string(from: Date()))] \(message)\n")
    }

    /// Appends a labelled event with its raw JSON body pretty-printed, for payload-shape
    /// debugging. Truncates very large bodies so one huge tool input can't dominate the log.
    static func logEvent(_ label: String, raw: Data) {
        guard isEnabled else { return }
        var body = String(data: raw, encoding: .utf8) ?? "<non-utf8 \(raw.count) bytes>"
        if body.count > 8_000 {
            body = String(body.prefix(8_000)) + "…<truncated>"
        }
        write("[\(stamp.string(from: Date()))] \(label)\n\(body)\n")
    }

    private static func write(_ text: String) {
        queue.async {
            let url = fileURL
            let fm = FileManager.default
            try? fm.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            guard let data = text.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url, options: [.atomic])
            }
            trimIfNeeded(url)
        }
    }

    /// Keeps the log bounded: when it passes `maxBytes`, rewrite it with the most recent
    /// half so long-running sessions don't accumulate an unbounded file.
    private static func trimIfNeeded(_ url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int, size > maxBytes,
              let data = try? Data(contentsOf: url) else { return }
        let keep = data.suffix(maxBytes / 2)
        try? keep.write(to: url, options: [.atomic])
    }
}
