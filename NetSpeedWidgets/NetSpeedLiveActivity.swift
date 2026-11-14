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
                HStack(spacing: 1) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(context.state.downShort)
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                }
                .foregroundStyle(Color(red: 0.118, green: 0.792, blue: 0.827))
            } compactTrailing: {
                HStack(spacing: 1) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                    Text(context.state.upShort)
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                }
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
            HStack {
                Text("网速 · \(context.state.networkLabel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                // System-driven timer — ticks every second WITHOUT Activity.update.
                // (Wall-clock refreshedAt freezes when iOS drops local updates.)
                Text(context.state.sessionStart, style: .timer)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            HStack(spacing: 16) {
                Text("↓ \(context.state.downLabel)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color(red: 0.118, green: 0.792, blue: 0.827))
                    .contentTransition(.numericText())
                    .id("down-\(context.state.seq)")
                Text("↑ \(context.state.upLabel)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color(red: 0.369, green: 0.949, blue: 0.659))
                    .contentTransition(.numericText())
                    .id("up-\(context.state.seq)")
                Spacer(minLength: 0)
            }
            .animation(.easeInOut(duration: 0.2), value: context.state.seq)
            Text("采样 \(context.state.refreshedAt.isEmpty ? "…" : context.state.refreshedAt)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary.opacity(0.85))
        }
        .padding(16)
        .activityBackgroundTint(Color(red: 0.016, green: 0.086, blue: 0.102).opacity(0.92))
    }
}
