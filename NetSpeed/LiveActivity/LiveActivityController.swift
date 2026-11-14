import ActivityKit
import Foundation
import UIKit

@MainActor
enum LiveActivityController {
    private static var current: Activity<NetSpeedActivityAttributes>?
    private static var seq: Int = 0
    private static var lastFingerprint: String?
    private static var lastUpdateAt: Date?
    private static var pendingCreate = false
    /// True when system accepted update() but did not apply content (budget).
    private static var contentStalled = false
    private static var sessionStart: Date = Date()
    private static let log = SpeedLogger.shared

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
        let auth = ActivityAuthorizationInfo()
        guard auth.areActivitiesEnabled else {
            log.error("island upsert blocked areActivitiesEnabled=false")
            return false
        }

        _ = resolvedActivity()

        seq &+= 1
        let now = Date()
        let refreshedAt = Self.clock.string(from: now)
        if resolvedActivity() == nil {
            sessionStart = now
        } else if let existing = resolvedActivity()?.content.state.sessionStart {
            sessionStart = existing
        }

        let state = NetSpeedActivityAttributes.ContentState(
            downLabel: downLabel,
            upLabel: upLabel,
            downShort: downShort,
            upShort: upShort,
            networkLabel: networkLabel,
            seq: seq,
            refreshedAt: refreshedAt,
            sessionStart: sessionStart,
            updatedAt: now
        )
        lastFingerprint = "\(seq)|\(refreshedAt)|\(downShort)|\(upShort)"

        let stale = Date().addingTimeInterval(60 * 60)
        let content = ActivityContent(state: state, staleDate: stale, relevanceScore: 100)
        let activityCount = Activity<NetSpeedActivityAttributes>.activities.count

        if let activity = resolvedActivity() {
            await BackgroundKeepAlive.shared.withAudioYielded {
                await activity.update(content)
            }
            // Drop duplicates only.
            for extra in Activity<NetSpeedActivityAttributes>.activities where extra.id != activity.id {
                await extra.end(nil, dismissalPolicy: .immediate)
            }

            let presented = activity.content.state
            let applied = presented.seq == seq
            if applied {
                contentStalled = false
                lastUpdateAt = now
                pendingCreate = false
                log.info(
                    "island update ok id=\(activity.id.prefix(8)) seq=\(seq) ↓\(downShort) ↑\(upShort) n=\(activityCount) force=\(force) at=\(refreshedAt) presentedAt=\(presented.refreshedAt) presentedSeq=\(presented.seq)"
                )
                return true
            }

            // update() returned but content unchanged — iOS dropped it.
            contentStalled = true
            pendingCreate = true
            log.error(
                "island UPDATE DROPPED by system seq=\(seq) at=\(refreshedAt) presentedSeq=\(presented.seq) presentedAt=\(presented.refreshedAt) ↓\(presented.downShort) — lock wall-clock frozen; timer still ticks"
            )
            return false
        }

        guard UIApplication.shared.applicationState == .active else {
            pendingCreate = true
            log.error("island request skipped (app not active, pendingCreate=true)")
            lastFingerprint = nil
            return false
        }

        do {
            // If previous activity stalled, end it and create fresh so content can apply again.
            if contentStalled {
                for staleActivity in Activity<NetSpeedActivityAttributes>.activities {
                    await staleActivity.end(nil, dismissalPolicy: .immediate)
                }
                current = nil
                sessionStart = now
                contentStalled = false
                log.info("island recreate after stalled updates")
            }

            let requestState = NetSpeedActivityAttributes.ContentState(
                downLabel: downLabel,
                upLabel: upLabel,
                downShort: downShort,
                upShort: upShort,
                networkLabel: networkLabel,
                seq: seq,
                refreshedAt: refreshedAt,
                sessionStart: sessionStart,
                updatedAt: now
            )
            let activity = try Activity.request(
                attributes: NetSpeedActivityAttributes(title: "网速"),
                content: ActivityContent(state: requestState, staleDate: stale, relevanceScore: 100),
                pushType: nil
            )
            current = activity
            lastUpdateAt = now
            pendingCreate = false
            contentStalled = false
            log.info("island request ok id=\(activity.id.prefix(8)) seq=\(seq) ↓\(downShort) ↑\(upShort) at=\(refreshedAt)")
            return true
        } catch {
            log.error("island request failed: \(error.localizedDescription)")
            lastFingerprint = nil
            pendingCreate = true
            return false
        }
    }

    @available(iOS 16.2, *)
    static func flushPendingCreateIfNeeded(
        downLabel: String,
        upLabel: String,
        downShort: String,
        upShort: String,
        networkLabel: String
    ) async {
        guard pendingCreate || contentStalled || resolvedActivity() == nil else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        if contentStalled {
            for activity in Activity<NetSpeedActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            current = nil
            contentStalled = false
            pendingCreate = true
            log.info("island end stalled before recreate")
        }
        _ = await upsert(
            downLabel: downLabel,
            upLabel: upLabel,
            downShort: downShort,
            upShort: upShort,
            networkLabel: networkLabel,
            force: true
        )
    }

    static func end() {
        guard #available(iOS 16.2, *) else { return }
        lastFingerprint = nil
        contentStalled = false
        let activities = Activity<NetSpeedActivityAttributes>.activities
        current = nil
        log.info("island end count=\(activities.count)")
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

    @available(iOS 16.2, *)
    static func diagnosticSummary() -> String {
        let auth = ActivityAuthorizationInfo()
        let n = Activity<NetSpeedActivityAttributes>.activities.count
        let stall = contentStalled ? " stalled" : ""
        return "LA enabled=\(auth.areActivitiesEnabled) freq=\(auth.frequentPushesEnabled) activities=\(n) seq=\(seq)\(stall)"
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
