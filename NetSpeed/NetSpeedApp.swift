import SwiftUI

@main
struct NetSpeedApp: App {
    @StateObject private var monitor = TrafficMonitor()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(monitor)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { newPhase in
                    monitor.handleScenePhase(newPhase)
                }
        }
    }
}
