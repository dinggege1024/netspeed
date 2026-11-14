import Foundation

enum SpeedTestPhase: String {
    case idle
    case ping
    case download
    case upload
    case done
    case error
}

struct SpeedTestResult {
    var pingMs: Double?
    var downloadMbps: Double?
    var uploadMbps: Double?
    var error: String?
}

@MainActor
final class SpeedTestService: ObservableObject {
    @Published private(set) var phase: SpeedTestPhase = .idle
    @Published private(set) var result = SpeedTestResult()

    private var task: Task<Void, Never>?

    var isBusy: Bool {
        switch phase {
        case .ping, .download, .upload: return true
        default: return false
        }
    }

    func toggle() {
        if isBusy {
            task?.cancel()
            task = nil
            phase = .idle
            return
        }
        task = Task { await run() }
    }

    private func run() async {
        result = SpeedTestResult()
        do {
            phase = .ping
            result.pingMs = try await measurePing()
            guard !Task.isCancelled else { phase = .idle; return }

            phase = .download
            result.downloadMbps = try await measureDownload()
            guard !Task.isCancelled else { phase = .idle; return }

            phase = .upload
            result.uploadMbps = try await measureUpload()
            guard !Task.isCancelled else { phase = .idle; return }

            phase = .done
        } catch is CancellationError {
            phase = .idle
        } catch {
            result.error = error.localizedDescription
            phase = .error
        }
    }

    private func measurePing() async throws -> Double {
        var samples: [Double] = []
        for _ in 0..<3 {
            let url = URL(string: "https://speed.cloudflare.com/__down?bytes=10&t=\(Date().timeIntervalSince1970)")!
            let start = Date()
            let (_, response) = try await URLSession.shared.data(from: url)
            _ = response
            samples.append(Date().timeIntervalSince(start) * 1000)
        }
        samples.sort()
        return samples[samples.count / 2]
    }

    private func measureDownload() async throws -> Double {
        let url = URL(string: "https://speed.cloudflare.com/__down?bytes=12000000&t=\(Date().timeIntervalSince1970)")!
        let start = Date()
        let (data, _) = try await URLSession.shared.data(from: url)
        let elapsed = max(Date().timeIntervalSince(start), 0.001)
        return Double(data.count) * 8 / elapsed / 1_000_000
    }

    private func measureUpload() async throws -> Double {
        let url = URL(string: "https://speed.cloudflare.com/__up")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let payload = Data(count: 4_000_000)
        let start = Date()
        let (_, _) = try await URLSession.shared.upload(for: request, from: payload)
        let elapsed = max(Date().timeIntervalSince(start), 0.001)
        return Double(payload.count) * 8 / elapsed / 1_000_000
    }
}
