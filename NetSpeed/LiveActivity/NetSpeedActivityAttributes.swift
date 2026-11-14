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
    }

    var title: String
}
