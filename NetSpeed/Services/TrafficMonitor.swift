import Combine
import Darwin
import Foundation
import Network
import SwiftUI
import UIKit

struct SpeedSample: Identifiable, Equatable {
    let id = UUID()
    let at: Date
    let down: Double
    let up: Double
}

@MainActor
final class TrafficMonitor: ObservableObject {
    static let intervalOptions: [TimeInterval] = [2, 5, 10, 15, 30]

    @Published private(set) var downSpeed: Double = 0
    @Published private(set) var upSpeed: Double = 0
    @Published private(set) var totalDown: UInt64 = 0
    @Published private(set) var totalUp: UInt64 = 0
    @Published private(set) var history: [SpeedSample] = []
    @Published private(set) var isMonitoring = true
    @Published private(set) var networkLabel = "检测中"
    @Published private(set) var networkDetail = "…"
    @Published var unit: SpeedUnit = .autoBytes
    @Published private(set) var liveActivityOn = false
    @Published private(set) var isInBackground = false
    /// Island average window + push cadence (seconds).
    @Published private(set) var sampleInterval: TimeInterval
    @Published private(set) var rawDown: Double = 0
    @Published private(set) var rawUp: Double = 0
    /// Last values pushed to Dynamic Island (window average).
    @Published private(set) var islandDown: Double = 0
    @Published private(set) var islandUp: Double = 0
    /// Keep process alive in background so island can keep updating (uses audio session).
    @Published private(set) var keepAliveEnabled: Bool
    @Published private(set) var lastIslandPushAt: Date?
    @Published private(set) var diagnosticLine: String = "…"

    private var sourceTimer: DispatchSourceTimer?
    private var ticksSinceHeartbeat = 0
    private var lastRx: UInt64?
    private var lastTx: UInt64?
    private var lastAt: Date?
    private var lastTrafficAt: Date?
    /// Start of the current island averaging window.
    private var islandAnchorRx: UInt64?
    private var islandAnchorTx: UInt64?
    private var islandAnchorAt: Date?
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "com.local.netspeed.path")
    private let historyLimit = 120
    private let defaultsKey = "netspeed.sampleInterval"
    private let keepAliveKey = "netspeed.keepAlive"
    private let foregroundInterval: TimeInterval = 1.0
    private let idleZeroAfter: TimeInterval = 60.0
    private let noiseFloorBps: Double = 5 * 1024
    private let log = SpeedLogger.shared

    /// App UI: 1s. Background / island sampling: exactly sampleInterval.
    private var activeInterval: TimeInterval {
        isInBackground ? sampleInterval : foregroundInterval
    }

    var historyWindowLabel: String {
        let seconds = Int(foregroundInterval * Double(historyLimit))
        if seconds >= 60 {
            return "近 \(max(1, seconds / 60)) 分钟"
        }
        return "近 \(seconds) 秒"
    }

    var intervalLabel: String {
        "灵动岛 \(Int(sampleInterval)) 秒均值"
    }

    var statusLabel: String {
        if !isMonitoring { return "监控已暂停 · 灵动岛已结束" }
        if isInBackground {
            let alive = keepAliveEnabled ? "后台保活中" : "后台（易被挂起）"
            return "\(intervalLabel) · \(alive)"
        }
        return "App 实时 · 岛每 \(Int(sampleInterval)) 秒均值刷新"
    }

    init() {
        // Prefer 2s island push (user request). Migrate once from older defaults.
        let intervalMigratedKey = "netspeed.intervalMigrated2s"
        if !UserDefaults.standard.bool(forKey: intervalMigratedKey) {
            sampleInterval = 2
            UserDefaults.standard.set(2.0, forKey: defaultsKey)
            UserDefaults.standard.set(true, forKey: intervalMigratedKey)
        } else {
            let saved = UserDefaults.standard.double(forKey: defaultsKey)
            sampleInterval = Self.intervalOptions.contains(saved) ? saved : 2
        }
        // Keep-alive ON so lock screen keeps receiving updates (process otherwise
        // suspends → refreshedAt freezes). Audio is stopped while app is active
        // and paused around each Activity.update.
        let kaMigratedKey = "netspeed.keepAliveMigratedOn2"
        if !UserDefaults.standard.bool(forKey: kaMigratedKey) {
            keepAliveEnabled = true
            UserDefaults.standard.set(true, forKey: keepAliveKey)
            UserDefaults.standard.set(true, forKey: kaMigratedKey)
        } else {
            keepAliveEnabled = UserDefaults.standard.bool(forKey: keepAliveKey)
        }
        BackgroundKeepAlive.shared.onWakeHint = { [weak self] in
            self?.handleWakeHint(reason: "keepalive-hint")
        }
        startPathMonitor()
        start()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            isInBackground = false
            if !keepAliveEnabled {
                BackgroundRunner.shared.end()
            }
            log.info("scene=active")
            if isMonitoring {
                handleWakeHint(reason: "scene-active")
                Task { await recreateIslandIfNeeded() }
            }
        case .inactive:
            // Lock button often hits inactive first — arm keep-alive before suspend.
            log.info("scene=inactive (arm keepalive)")
            if isMonitoring {
                BackgroundRunner.shared.begin()
                syncKeepAlive()
            }
        case .background:
            isInBackground = true
            log.info("scene=background keepAlive=\(keepAliveEnabled)")
            guard isMonitoring else { return }
            BackgroundRunner.shared.begin()
            syncKeepAlive()
            resetIslandWindow()
            ensureTimerRunning(fireImmediately: true)
        @unknown default:
            break
        }
    }

    /// Called on unlock / audio revive / become active.
    func handleWakeHint(reason: String) {
        guard isMonitoring else { return }
        log.info("wakeHint reason=\(reason) bg=\(isInBackground)")
        syncKeepAlive()
        // Locked: only keep process alive — never spam Activity.update
        // (that burns presentation budget → lock-screen clock freezes).
        guard !isInBackground else { return }
        ensureTimerRunning(fireImmediately: true)
        Task {
            await recreateIslandIfNeeded()
            await pushIsland(force: true)
        }
    }

    func setKeepAliveEnabled(_ enabled: Bool) {
        keepAliveEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: keepAliveKey)
        log.info("keepAlive=\(enabled)")
        syncKeepAlive()
    }

    func setSampleInterval(_ seconds: TimeInterval) {
        guard Self.intervalOptions.contains(seconds) else { return }
        guard seconds != sampleInterval else { return }
        sampleInterval = seconds
        UserDefaults.standard.set(seconds, forKey: defaultsKey)
        log.info("islandInterval=\(Int(seconds))s")
        resetIslandWindow()
        if isMonitoring, isInBackground {
            ensureTimerRunning(fireImmediately: true)
        }
    }

    func toggleMonitoring() {
        if isMonitoring { stop() } else { start() }
    }

    func toggleUnit() {
        unit = unit == .autoBytes ? .mbps : .autoBytes
        Task { await pushIsland(force: true) }
    }

    func start() {
        isMonitoring = true
        lastRx = nil
        lastTx = nil
        lastAt = nil
        lastTrafficAt = nil
        downSpeed = 0
        upSpeed = 0
        rawDown = 0
        rawUp = 0
        islandDown = 0
        islandUp = 0
        resetIslandWindow()
        log.info("monitor=start ui=\(foregroundInterval)s island=\(sampleInterval)s")
        ensureTimerRunning(fireImmediately: true)
        syncKeepAlive()
    }

    func stop() {
        isMonitoring = false
        stopTimer()
        downSpeed = 0
        upSpeed = 0
        islandDown = 0
        islandUp = 0
        lastTrafficAt = nil
        BackgroundKeepAlive.shared.stop()
        BackgroundRunner.shared.end()
        LiveActivityController.end()
        liveActivityOn = false
        log.info("monitor=stop")
    }

    private func syncKeepAlive() {
        // Never play keep-alive audio while the app is active — it fights
        // Dynamic Island chrome and is useless for presentation.
        let appActive = UIApplication.shared.applicationState == .active
        let wantAudio = keepAliveEnabled && isMonitoring && !appActive
        if wantAudio {
            BackgroundKeepAlive.shared.start()
            BackgroundKeepAlive.shared.ensureRunning()
            BackgroundRunner.shared.begin()
        } else {
            BackgroundKeepAlive.shared.stop()
            if isMonitoring, isInBackground {
                BackgroundRunner.shared.begin()
            } else if !isInBackground {
                BackgroundRunner.shared.end()
            }
        }
        refreshDiagnostic()
    }

    private func refreshDiagnostic() {
        let tickAge: String
        if let last = SpeedLogger.shared.lastTickAt {
            tickAge = String(format: "%.0fs", Date().timeIntervalSince(last))
        } else {
            tickAge = "never"
        }
        let islandAge: String
        if let last = lastIslandPushAt {
            islandAge = String(format: "%.0fs", Date().timeIntervalSince(last))
        } else {
            islandAge = "never"
        }
        var la = "LA=?"
        if #available(iOS 16.2, *) {
            la = LiveActivityController.diagnosticSummary()
        }
        diagnosticLine =
            "tickAge=\(tickAge) islandAge=\(islandAge) ka=\(BackgroundKeepAlive.shared.statusLine) bg=\(isInBackground) \(la)"
    }

    private func resetIslandWindow() {
        islandAnchorRx = nil
        islandAnchorTx = nil
        islandAnchorAt = nil
    }

    private var loopTimer: Timer?

    private func ensureTimerRunning(fireImmediately: Bool) {
        stopTimer()
        let interval = activeInterval
        // RunLoop .common keeps firing during tracking / lock transitions better
        // than a plain DispatchSource in some iOS versions.
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        loopTimer = timer
        if fireImmediately {
            Task { await tick() }
        }
        log.debug("timer repeating=\(interval)s fireNow=\(fireImmediately) bg=\(isInBackground) mode=common")
    }

    private func stopTimer() {
        sourceTimer?.setEventHandler {}
        sourceTimer?.cancel()
        sourceTimer = nil
        loopTimer?.invalidate()
        loopTimer = nil
    }

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.apply(path: path)
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    private func apply(path: NWPath) {
        if path.status != .satisfied {
            networkLabel = "离线"
            networkDetail = "无可用网络"
            return
        }
        if path.usesInterfaceType(.wifi) {
            networkLabel = "Wi‑Fi"
            networkDetail = "无线局域网"
        } else if path.usesInterfaceType(.cellular) {
            networkLabel = "蜂窝"
            networkDetail = "移动数据"
        } else if path.usesInterfaceType(.wiredEthernet) {
            networkLabel = "有线"
            networkDetail = "Ethernet"
        } else {
            networkLabel = "已连接"
            networkDetail = "网络可用"
        }
        // Don't push island here — wait for the average window.
    }

    private func tick() async {
        guard isMonitoring else { return }
        log.noteTick()

        if keepAliveEnabled, isInBackground {
            BackgroundKeepAlive.shared.ensureRunning()
        }

        ticksSinceHeartbeat &+= 1
        // Heartbeat every ~10 foreground ticks or every background tick window.
        let heartbeatEvery = isInBackground ? 1 : 10
        if ticksSinceHeartbeat >= heartbeatEvery {
            ticksSinceHeartbeat = 0
            refreshDiagnostic()
            log.info("heartbeat \(diagnosticLine)")
        }

        let counters = Self.readTrafficBytes()
        totalDown = counters.rx
        totalUp = counters.tx
        let now = Date()

        // Open island window on first sample after reset.
        if islandAnchorRx == nil {
            islandAnchorRx = counters.rx
            islandAnchorTx = counters.tx
            islandAnchorAt = now
        }

        defer {
            lastRx = counters.rx
            lastTx = counters.tx
            lastAt = now
        }

        guard let prevRx = lastRx, let prevTx = lastTx, let prevAt = lastAt else {
            log.debug("baseline rx=\(counters.rx) tx=\(counters.tx)")
            // First paint only in foreground — background create is rejected by iOS
            // and burning failed requests helps nothing for lock-screen clock.
            if !isInBackground {
                await publishIsland(down: 0, up: 0, force: true)
            }
            return
        }

        if counters.rx < prevRx || counters.tx < prevTx {
            log.info("counter wrap/reset — resync")
            resetIslandWindow()
            islandAnchorRx = counters.rx
            islandAnchorTx = counters.tx
            islandAnchorAt = now
            return
        }

        // —— App UI rate (1s in foreground, sampleInterval in background) ——
        let deltaRx = counters.rx &- prevRx
        let deltaTx = counters.tx &- prevTx
        let dt = max(now.timeIntervalSince(prevAt), activeInterval * 0.5)
        let nextRawDown = Double(deltaRx) / dt
        let nextRawUp = Double(deltaTx) / dt
        rawDown = nextRawDown
        rawUp = nextRawUp
        applyDisplaySpeeds(down: nextRawDown, up: nextRawUp, at: now)

        if !isInBackground {
            history.append(SpeedSample(at: now, down: downSpeed, up: upSpeed))
            if history.count > historyLimit {
                history.removeFirst(history.count - historyLimit)
            }
        }

        // —— Island: only refresh when the average window is full ——
        await maybeRefreshIsland(counters: counters, now: now)
    }

    private func applyDisplaySpeeds(down: Double, up: Double, at: Date) {
        let combined = down + up
        if combined >= noiseFloorBps {
            lastTrafficAt = at
            downSpeed = down
            upSpeed = up
        } else {
            downSpeed = 0
            upSpeed = 0
        }
        let idleFor = lastTrafficAt.map { at.timeIntervalSince($0) } ?? .infinity
        if idleFor >= idleZeroAfter {
            downSpeed = 0
            upSpeed = 0
        }
    }

    private func maybeRefreshIsland(counters: (rx: UInt64, tx: UInt64), now: Date) async {
        guard let anchorRx = islandAnchorRx,
              let anchorTx = islandAnchorTx,
              let anchorAt = islandAnchorAt else { return }

        let elapsed = now.timeIntervalSince(anchorAt)
        // Always wait for a full average window (e.g. 5s) — foreground or lock screen.
        // Closing early produced 1s burst windows → lots of 0B while watching video.
        guard elapsed >= sampleInterval - 0.05 else { return }

        if counters.rx < anchorRx || counters.tx < anchorTx {
            resetIslandWindow()
            return
        }

        let windowDown = Double(counters.rx &- anchorRx) / elapsed
        let windowUp = Double(counters.tx &- anchorTx) / elapsed
        // Always push the real window average. Holding the last speed made the
        // island look frozen (same KB for many cycles) while logs still said ok.
        var showDown = windowDown
        var showUp = windowUp
        if windowDown + windowUp < noiseFloorBps {
            showDown = 0
            showUp = 0
        } else {
            lastTrafficAt = now
        }

        log.info(
            String(
                format: "island window=%.1fs avg=↓%.0f ↑%.0f → push (raw ↓%.0f ↑%.0f)",
                elapsed,
                showDown,
                showUp,
                windowDown,
                windowUp
            )
        )

        await publishIsland(down: showDown, up: showUp, force: false)

        // Start next average window from this sample.
        islandAnchorRx = counters.rx
        islandAnchorTx = counters.tx
        islandAnchorAt = now
    }

    private func publishIsland(down: Double, up: Double, force: Bool) async {
        islandDown = down
        islandUp = up
        await pushIsland(force: force)
    }

    private func recreateIslandIfNeeded() async {
        guard #available(iOS 16.2, *) else { return }
        await LiveActivityController.flushPendingCreateIfNeeded(
            downLabel: SpeedFormatter.format(islandDown, unit: unit),
            upLabel: SpeedFormatter.format(islandUp, unit: unit),
            downShort: SpeedFormatter.compact(islandDown),
            upShort: SpeedFormatter.compact(islandUp),
            networkLabel: networkLabel
        )
        refreshDiagnostic()
    }

    private func pushIsland(force: Bool = false) async {
        guard isMonitoring else { return }
        guard #available(iOS 16.2, *) else {
            liveActivityOn = false
            return
        }
        let ok = await LiveActivityController.upsert(
            downLabel: SpeedFormatter.format(islandDown, unit: unit),
            upLabel: SpeedFormatter.format(islandUp, unit: unit),
            downShort: SpeedFormatter.compact(islandDown),
            upShort: SpeedFormatter.compact(islandUp),
            networkLabel: networkLabel,
            force: force
        )
        liveActivityOn = ok
        if ok {
            lastIslandPushAt = Date()
            log.info(
                String(
                    format: "island push committed ↓%@ ↑%@ force=%@ age=0s",
                    SpeedFormatter.compact(islandDown),
                    SpeedFormatter.compact(islandUp),
                    force ? "true" : "false"
                )
            )
        } else {
            // Must not pretend the lock-screen clock advanced.
            log.error("island push returned false — lock UI not updated")
        }
        refreshDiagnostic()
    }

    nonisolated static func readTrafficBytes() -> (rx: UInt64, tx: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddr) }

        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            let name = String(cString: current.pointee.ifa_name)
            let family = Int32(current.pointee.ifa_addr.pointee.sa_family)
            if family == AF_LINK, Self.isPrimaryInterface(name), let data = current.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self)
                rx += UInt64(networkData.pointee.ifi_ibytes)
                tx += UInt64(networkData.pointee.ifi_obytes)
            }
            ptr = current.pointee.ifa_next
        }
        return (rx, tx)
    }

    nonisolated private static func isPrimaryInterface(_ name: String) -> Bool {
        if name.hasPrefix("en") { return true }
        if name.hasPrefix("pdp_ip") { return true }
        return false
    }
}
