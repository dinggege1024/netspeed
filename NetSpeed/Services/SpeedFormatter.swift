import Foundation

enum SpeedUnit: String, CaseIterable, Identifiable {
    case autoBytes
    case mbps

    var id: String { rawValue }

    var toggleTitle: String {
        switch self {
        case .autoBytes: return "改用 Mbps"
        case .mbps: return "改用 KB/s"
        }
    }
}

enum SpeedFormatter {
    static func format(_ bytesPerSec: Double, unit: SpeedUnit) -> String {
        let value = max(0, bytesPerSec)
        switch unit {
        case .mbps:
            let mbps = value * 8 / 1_000_000
            if mbps >= 100 { return String(format: "%.0f Mbps", mbps) }
            if mbps >= 10 { return String(format: "%.1f Mbps", mbps) }
            return String(format: "%.2f Mbps", mbps)
        case .autoBytes:
            let units = ["B/s", "KB/s", "MB/s", "GB/s"]
            var size = value
            var index = 0
            while size >= 1024, index < units.count - 1 {
                size /= 1024
                index += 1
            }
            if size >= 100 { return String(format: "%.0f %@", size, units[index]) }
            if size >= 10 { return String(format: "%.1f %@", size, units[index]) }
            return String(format: "%.2f %@", size, units[index])
        }
    }

    /// Compact labels for Dynamic Island (tight width).
    static func compact(_ bytesPerSec: Double) -> String {
        let value = max(0, bytesPerSec)
        if value < 1024 { return String(format: "%.0fB", value) }
        let kb = value / 1024
        if kb < 1024 {
            return kb >= 100 ? String(format: "%.0fK", kb) : String(format: "%.1fK", kb)
        }
        let mb = kb / 1024
        if mb < 1024 {
            return mb >= 100 ? String(format: "%.0fM", mb) : String(format: "%.1fM", mb)
        }
        return String(format: "%.1fG", mb / 1024)
    }

    static func dataSize(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(bytes)
        var index = 0
        while size >= 1024, index < units.count - 1 {
            size /= 1024
            index += 1
        }
        return String(format: size >= 100 ? "%.0f %@" : "%.1f %@", size, units[index])
    }
}
