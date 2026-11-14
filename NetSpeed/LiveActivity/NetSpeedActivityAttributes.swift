import ActivityKit
import Foundation

struct NetSpeedActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var downLabel: String
        var upLabel: String
        var downShort: String
        var upShort: String
        var networkLabel: String
        /// Forces island redraw when numeric labels round to the same string.
        var seq: Int = 0
        /// Wall-clock string snapshot (may freeze if system drops updates).
        var refreshedAt: String = ""
        /// Fixed at Live Activity create — lock screen uses Text(style: .timer)
        /// so seconds keep ticking even when Activity.update is dropped.
        var sessionStart: Date = Date()
        /// Last speed sample time (for relative "x秒前").
        var updatedAt: Date = Date()
    }

    var title: String
}
