import AVFoundation
import Foundation

/// Keeps the process runnable in background so Live Activity can keep
/// receiving local updates. Uses a silent looping audio session
/// (personal / sideload use — costs battery; not for App Store abuse).
@MainActor
final class BackgroundKeepAlive {
    static let shared = BackgroundKeepAlive()

    private var player: AVAudioPlayer?
    private(set) var isRunning = false

    func start() {
        guard !isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let player = try AVAudioPlayer(data: Self.silentWavData())
            player.numberOfLoops = -1
            // Some iOS versions suspend fully-muted players; keep a tiny volume.
            player.volume = 0.01
            player.prepareToPlay()
            guard player.play() else { return }
            self.player = player
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    /// Minimal 1s mono 16-bit PCM WAV of silence.
    private static func silentWavData() -> Data {
        let sampleRate = 8000
        let seconds = 1
        let numSamples = sampleRate * seconds
        let dataSize = numSamples * 2
        var data = Data()

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
        appendUInt16(1) // PCM
        appendUInt16(1) // mono
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2))
        appendUInt16(2)
        appendUInt16(16)
        data.append(contentsOf: Array("data".utf8))
        appendUInt32(UInt32(dataSize))
        data.append(Data(count: dataSize))
        return data
    }
}
