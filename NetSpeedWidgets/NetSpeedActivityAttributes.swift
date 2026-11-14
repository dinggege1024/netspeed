import ActivityKit
import Foundation

/// Must match the main app definition for ActivityKit.
struct NetSpeedActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var downLabel: String
        var upLabel: String
        var downShort: String
        var upShort: String
        var networkLabel: String
        var seq: Int = 0
    }

    var title: String
}
