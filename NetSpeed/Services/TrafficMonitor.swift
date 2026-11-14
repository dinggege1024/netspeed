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
    static let intervalOptions: [TimeInterval] = [1, 2, 5, 10, 15, 30]

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

    private var sourceTimer: DispatchSourceTimer?
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
            return "\(intervalLabel) · 后台"
        }
        return "App 实时 · 岛每 \(Int(sampleInterval)) 秒均值刷新"
    }

    init() {
        let saved = UserDefaults.standard.double(forKey: defaultsKey)
        if Self.intervalOptions.contains(saved) {
            sampleInterval = saved
        } else {
            sampleInterval = 5
        }
        startPathMonitor()
        start()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            isInBackground = false
            BackgroundRunner.shared.end()
            log.info("scene=active")
            if isMonitoring {
                resetIslandWindow()
                ensureTimerRunning(fireImmediately: true)
            }
        case .inactive:
            log.debug("scene=inactive")
            if isMonitoring {
                BackgroundRunner.shared.begin()
            }
        case .background:
            isInBackground = true
            log.info("scene=background")
            guard isMonitoring else { return }
            BackgroundRunner.shared.begin()
            resetIslandWindow()
            ensureTimerRunning(fireImmediately: true)
        @unknown default:
            break
        }
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
    }

    func stop() {
        isMonitoring = false
        stopTimer()
        downSpeed = 0
        upSpeed = 0
        islandDown = 0
        islandUp = 0
        lastTrafficAt = nil
        BackgroundRunner.shared.end()
        LiveActivityController.end()
        liveActivityOn = false
        log.info("monitor=stop")
    }

    private func resetIslandWindow() {
        islandAnchorRx = nil
        islandAnchorTx = nil
        islandAnchorAt = nil
    }

    private func ensureTimerRunning(fireImmediately: Bool) {
        stopTimer()
        let interval = activeInterval
        let timer = DispatchSource.makeTimerSource(queue: .main)
        let deadline: DispatchTime = fireImmediately ? .now() : .now() + interval
        timer.schedule(deadline: deadline, repeating: interval, leeway: .milliseconds(80))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.tick()
            }
        }
        timer.resume()
        sourceTimer = timer
        log.debug("timer repeating=\(interval)s fireNow=\(fireImmediately) bg=\(isInBackground)")
    }

    private func stopTimer() {
        sourceTimer?.setEventHandler {}
        sourceTimer?.cancel()
        sourceTimer = nil
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
            // First paint on island so user sees it is alive; then wait full window.
            await publishIsland(down: 0, up: 0, force: true)
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
        // Background ticks are already spaced by sampleInterval — always close the window.
        // Foreground ticks every 1s — wait until window is full.
        let windowReady = isInBackground || elapsed >= sampleInterval - 0.05
        guard windowReady else { return }
        guard elapsed >= 0.2 else { return }

        if counters.rx < anchorRx || counters.tx < anchorTx {
            resetIslandWindow()
            return
        }

        let windowDown = Double(counters.rx &- anchorRx) / elapsed
        let windowUp = Double(counters.tx &- anchorTx) / elapsed
        var showDown = windowDown
        var showUp = windowUp
        if windowDown + windowUp < noiseFloorBps {
            showDown = 0
            showUp = 0
        }
        let idleFor = lastTrafficAt.map { now.timeIntervalSince($0) } ?? .infinity
        if idleFor >= idleZeroAfter {
            showDown = 0
            showUp = 0
        }

        log.info(
            String(
                format: "island window=%.1fs avg=↓%.0f ↑%.0f → push",
                elapsed,
                showDown,
                showUp
            )
        )

        await publishIsland(down: showDown, up: showUp, force: true)

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

    private func pushIsland(force: Bool = false) async {
        guard isMonitoring else { return }
        guard #available(iOS 16.2, *) else {
            liveActivityOn = false
            return
        }
        liveActivityOn = await LiveActivityController.upsert(
            downLabel: SpeedFormatter.format(islandDown, unit: unit),
            upLabel: SpeedFormatter.format(islandUp, unit: unit),
            downShort: SpeedFormatter.compact(islandDown),
            upShort: SpeedFormatter.compact(islandUp),
            networkLabel: networkLabel,
            force: force
        )
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
