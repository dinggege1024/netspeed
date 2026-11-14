import ActivityKit
import SwiftUI
import WidgetKit

struct NetSpeedLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NetSpeedActivityAttributes.self) { context in
            lockScreen(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(Color(red: 0.118, green: 0.792, blue: 0.827))
                        Text("下行")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .foregroundStyle(Color(red: 0.369, green: 0.949, blue: 0.659))
                        Text("上行")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.downLabel)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Color(red: 0.118, green: 0.792, blue: 0.827))
                        Text(context.state.upLabel)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Color(red: 0.369, green: 0.949, blue: 0.659))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("网速监控中 · \(context.state.networkLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Text("↓\(context.state.downShort)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color(red: 0.118, green: 0.792, blue: 0.827))
            } compactTrailing: {
                Text("↑\(context.state.upShort)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color(red: 0.369, green: 0.949, blue: 0.659))
            } minimal: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(Color(red: 0.118, green: 0.792, blue: 0.827))
            }
        }
    }

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<NetSpeedActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("网速 · \(context.state.networkLabel)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Text("↓ \(context.state.downLabel)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color(red: 0.118, green: 0.792, blue: 0.827))
                Text("↑ \(context.state.upLabel)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color(red: 0.369, green: 0.949, blue: 0.659))
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .activityBackgroundTint(Color(red: 0.016, green: 0.086, blue: 0.102).opacity(0.92))
    }
}
