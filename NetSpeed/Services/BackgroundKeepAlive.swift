import AVFoundation
import Foundation
import UIKit

/// Keeps the process runnable after lock / background.
/// IMPORTANT: do NOT publish Now Playing / remote-control — that steals
/// Dynamic Island from our Live Activity and the speed disappears.
@MainActor
final class BackgroundKeepAlive {
    static let shared = BackgroundKeepAlive()

    private var player: AVAudioPlayer?
    private var wantsRunning = false
    private var observers: [NSObjectProtocol] = []
    private var watchdog: Timer?
    private(set) var isRunning = false
    private(set) var lastError: String?

    var onWakeHint: (() -> Void)?

    var isActuallyPlaying: Bool {
        player?.isPlaying == true
    }

    var statusLine: String {
        if !wantsRunning { return "off" }
        if isActuallyPlaying { return "playing" }
        if isRunning { return "started-but-not-playing" }
        return lastError.map { "failed:\($0)" } ?? "stopped"
    }

    func start() {
        wantsRunning = true
        installObserversIfNeeded()
        beginPlayback(reason: "start")
        startWatchdog()
    }

    func ensureRunning() {
        guard wantsRunning else { return }
        if isActuallyPlaying { return }
        SpeedLogger.shared.info("keepalive revive playing=\(isActuallyPlaying) running=\(isRunning)")
        beginPlayback(reason: "revive")
    }

    /// Pause audio around Activity.update — some iOS versions suppress
    /// Live Activity presentation while our playback session is active.
    func withAudioYielded<T>(_ work: () async -> T) async -> T {
        let wasPlaying = isActuallyPlaying
        if wasPlaying {
            player?.pause()
        }
        let result = await work()
        if wantsRunning, wasPlaying {
            if player?.play() != true {
                beginPlayback(reason: "after-yield")
            }
        }
        return result
    }

    func stop() {
        wantsRunning = false
        stopWatchdog()
        tearDownPlayback(reason: "stop")
        removeObservers()
    }

    private func startWatchdog() {
        stopWatchdog()
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.wantsRunning else { return }
                let playing = self.isActuallyPlaying
                SpeedLogger.shared.info("keepalive watchdog playing=\(playing)")
                if !playing {
                    self.beginPlayback(reason: "watchdog")
                    self.onWakeHint?()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
    }

    private func beginPlayback(reason: String) {
        do {
            let session = AVAudioSession.sharedInstance()
            // mixWithOthers: less likely to take over Dynamic Island chrome.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            player?.stop()
            let next = try AVAudioPlayer(data: Self.quietToneWavData())
            next.numberOfLoops = -1
            next.volume = 0.01
            next.prepareToPlay()
            guard next.play() else {
                lastError = "play()=false"
                isRunning = false
                SpeedLogger.shared.error("keepalive \(reason) play failed")
                return
            }
            player = next
            isRunning = true
            lastError = nil
            SpeedLogger.shared.info("keepalive \(reason) ok playing=true")
        } catch {
            lastError = error.localizedDescription
            isRunning = false
            SpeedLogger.shared.error("keepalive \(reason) error=\(error.localizedDescription)")
        }
    }

    private func tearDownPlayback(reason: String) {
        player?.stop()
        player = nil
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
        SpeedLogger.shared.info("keepalive \(reason) tornDown")
    }

    private func installObserversIfNeeded() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        })

        observers.append(center.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                SpeedLogger.shared.info("screen~lock")
                self?.beginPlayback(reason: "before-lock")
            }
        })

        observers.append(center.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                SpeedLogger.shared.info("screen~unlock")
                self?.beginPlayback(reason: "after-unlock")
                self?.onWakeHint?()
            }
        })

        observers.append(center.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                SpeedLogger.shared.info("app willResignActive")
                self?.beginPlayback(reason: "resign-active")
            }
        })

        observers.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                SpeedLogger.shared.info("app didBecomeActive")
                self?.ensureRunning()
                self?.onWakeHint?()
            }
        })
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        for obs in observers { center.removeObserver(obs) }
        observers.removeAll()
    }

    private func handleInterruption(_ note: Notification) {
        guard wantsRunning else { return }
        guard let info = note.userInfo,
              let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }
        switch type {
        case .began:
            SpeedLogger.shared.info("keepalive interruption began")
            isRunning = false
        case .ended:
            SpeedLogger.shared.info("keepalive interruption ended")
            beginPlayback(reason: "after-interruption")
            onWakeHint?()
        @unknown default:
            break
        }
    }

    private static func quietToneWavData() -> Data {
        let sampleRate = 8000
        let seconds = 2
        let numSamples = sampleRate * seconds
        let dataSize = numSamples * 2
        var data = Data()
        data.reserveCapacity(44 + dataSize)

        func appendUInt32(_ v: UInt32) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        func appendUInt16(_ v: UInt16) {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        appendUInt32(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(1)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2))
        appendUInt16(2)
        appendUInt16(16)
        data.append(contentsOf: Array("data".utf8))
        appendUInt32(UInt32(dataSize))

        let freq = 180.0
        let amp = 0.008
        for n in 0..<numSamples {
            let t = Double(n) / Double(sampleRate)
            let sample = Int16((sin(2 * Double.pi * freq * t) * amp * Double(Int16.max)).rounded())
            var le = sample.littleEndian
            withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
        }
        return data
    }
}
