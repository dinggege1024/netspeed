import Foundation
import OSLog

/// In-memory ring + on-disk log capped at 10MB.
@MainActor
final class SpeedLogger: ObservableObject {
    static let shared = SpeedLogger()

    private let logger = Logger(subsystem: "com.local.netspeed", category: "traffic")
    private let memoryLimit = 40
    private let maxFileBytes: UInt64 = 10 * 1024 * 1024
    private let ioQueue = DispatchQueue(label: "com.local.netspeed.log.io", qos: .utility)

    @Published private(set) var lines: [String] = []
    @Published private(set) var tickCount: Int = 0
    @Published private(set) var lastTickAt: Date?
    @Published private(set) var fileBytes: UInt64 = 0
    @Published private(set) var filePathDisplay: String = ""

    private let fileURL: URL
    private let backupURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("netspeed.log")
        backupURL = dir.appendingPathComponent("netspeed.log.1")
        filePathDisplay = fileURL.lastPathComponent
        refreshFileSize()
        info("logger ready max=\(maxFileBytes / 1024 / 1024)MB path=\(fileURL.path)")
    }

    var fileSizeLabel: String {
        let mb = Double(fileBytes) / 1024 / 1024
        return String(format: "%.2f / 10 MB", mb)
    }

    func info(_ message: String) {
        append(level: "I", message)
        logger.info("\(message, privacy: .public)")
    }

    func debug(_ message: String) {
        append(level: "D", message)
        logger.debug("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        append(level: "E", message)
        logger.error("\(message, privacy: .public)")
    }

    func noteTick() {
        tickCount &+= 1
        lastTickAt = Date()
    }

    func clearFile() {
        ioQueue.async { [fileURL, backupURL] in
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: backupURL)
            DispatchQueue.main.async { [weak self] in
                self?.fileBytes = 0
                self?.info("log file cleared")
            }
        }
    }

    private func append(level: String, _ message: String) {
        let stamp = Self.timeFormatter.string(from: Date())
        let line = "\(stamp) [\(level)] \(message)"
        lines.append(line)
        if lines.count > memoryLimit {
            lines.removeFirst(lines.count - memoryLimit)
        }
        persist(line + "\n")
    }

    private func persist(_ chunk: String) {
        let url = fileURL
        let backup = backupURL
        let maxBytes = maxFileBytes
        ioQueue.async { [weak self] in
            guard let data = chunk.data(using: .utf8) else { return }
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            do {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                return
            }

            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
            if size > maxBytes {
                Self.rotate(active: url, backup: backup, maxBytes: maxBytes)
            }
            let newSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
            let backupSize = (try? FileManager.default.attributesOfItem(atPath: backup.path)[.size] as? UInt64) ?? 0
            DispatchQueue.main.async {
                self?.fileBytes = newSize + backupSize
            }
        }
    }

    /// Keep at most ~10MB total: current log + one rotated half.
    private static func rotate(active: URL, backup: URL, maxBytes: UInt64) {
        let fm = FileManager.default
        try? fm.removeItem(at: backup)
        try? fm.moveItem(at: active, to: backup)

        // If backup alone exceeds cap, keep only the tail.
        if let attrs = try? fm.attributesOfItem(atPath: backup.path),
           let size = attrs[.size] as? UInt64,
           size > maxBytes,
           let handle = try? FileHandle(forReadingFrom: backup) {
            defer { try? handle.close() }
            let keep = maxBytes / 2
            let offset = size - keep
            try? handle.seek(toOffset: offset)
            let tail = (try? handle.readToEnd()) ?? Data()
            try? fm.removeItem(at: backup)
            try? tail.write(to: backup, options: .atomic)
        }

        fm.createFile(atPath: active.path, contents: nil)
        let banner = "—— rotated \(ISO8601DateFormatter().string(from: Date())) ——\n"
        if let data = banner.data(using: .utf8),
           let handle = try? FileHandle(forWritingTo: active) {
            defer { try? handle.close() }
            try? handle.write(contentsOf: data)
        }
    }

    private func refreshFileSize() {
        let active = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64) ?? 0
        let backup = (try? FileManager.default.attributesOfItem(atPath: backupURL.path)[.size] as? UInt64) ?? 0
        fileBytes = active + backup
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
}
