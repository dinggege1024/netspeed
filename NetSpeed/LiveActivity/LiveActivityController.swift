import ActivityKit
import Foundation

@MainActor
enum LiveActivityController {
    private static var current: Activity<NetSpeedActivityAttributes>?
    private static var seq: Int = 0
    private static var lastFingerprint: String?

    @available(iOS 16.2, *)
    @discardableResult
    static func upsert(
        downLabel: String,
        upLabel: String,
        downShort: String,
        upShort: String,
        networkLabel: String,
        force: Bool = false
    ) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }

        seq &+= 1
        let fingerprint = "\(downShort)|\(upShort)|\(networkLabel)|\(downLabel)|\(upLabel)"
        let state = NetSpeedActivityAttributes.ContentState(
            downLabel: downLabel,
            upLabel: upLabel,
            downShort: downShort,
            upShort: upShort,
            networkLabel: networkLabel,
            seq: seq
        )

        if !force, fingerprint == lastFingerprint, current != nil {
            return true
        }
        lastFingerprint = fingerprint

        let isIdle = (downShort == "0B" || downShort.hasPrefix("0.0"))
            && (upShort == "0B" || upShort.hasPrefix("0.0"))
        let stale = Date().addingTimeInterval(isIdle ? 60 : 120)
        let content = ActivityContent(state: state, staleDate: stale, relevanceScore: isIdle ? 20 : 100)

        if let activity = resolvedActivity() {
            // Await so the update lands before iOS suspends us.
            await activity.update(content)
            return true
        }

        do {
            current = try Activity.request(
                attributes: NetSpeedActivityAttributes(title: "网速"),
                content: content,
                pushType: nil
            )
            return true
        } catch {
            return false
        }
    }

    static func end() {
        guard #available(iOS 16.2, *) else { return }
        lastFingerprint = nil
        let activities = Activity<NetSpeedActivityAttributes>.activities
        current = nil
        for activity in activities {
            Task {
                await activity.end(activity.content, dismissalPolicy: .immediate)
            }
        }
    }

    @available(iOS 16.2, *)
    private static func resolvedActivity() -> Activity<NetSpeedActivityAttributes>? {
        if let current,
           Activity<NetSpeedActivityAttributes>.activities.contains(where: { $0.id == current.id }) {
            return current
        }
        let first = Activity<NetSpeedActivityAttributes>.activities.first
        current = first
        return first
    }
}
