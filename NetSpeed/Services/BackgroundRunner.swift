import UIKit

/// Holds leftover background runtime so Live Activity can keep updating
/// after leaving the app. iOS still eventually suspends us — this only
/// stretches the window.
@MainActor
final class BackgroundRunner {
    static let shared = BackgroundRunner()

    private var taskId: UIBackgroundTaskIdentifier = .invalid
    private var wantsRunning = false
    private var name = "netspeed.live-activity"

    var isActive: Bool { taskId != .invalid }

    func begin(name: String = "netspeed.live-activity") {
        self.name = name
        wantsRunning = true
        renew()
    }

    func end() {
        wantsRunning = false
        finishCurrent()
    }

    private func renew() {
        // End previous task only after a new one is granted when possible.
        let previous = taskId
        taskId = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            guard let self else { return }
            // Expiration: end this id, then try to claim another slice.
            if self.taskId != .invalid {
                UIApplication.shared.endBackgroundTask(self.taskId)
                self.taskId = .invalid
            }
            guard self.wantsRunning else { return }
            self.renew()
        }

        if previous != .invalid {
            UIApplication.shared.endBackgroundTask(previous)
        }

        if taskId == .invalid {
            wantsRunning = false
        }
    }

    private func finishCurrent() {
        guard taskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(taskId)
        taskId = .invalid
    }
}
