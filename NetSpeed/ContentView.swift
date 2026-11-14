import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject private var monitor: TrafficMonitor
    @StateObject private var speedTest = SpeedTestService()
    @ObservedObject private var logger = SpeedLogger.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.bgMid, Theme.bgDeep, Color.black],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    islandBanner
                    chartCard
                    networkCard
                    intervalCard
                    controls
                    speedTestCard
                    debugLogCard
                    Text("网速 · 纯 Swift · 灵动岛")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("网速")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
            Text(monitor.statusLabel)
                .font(.subheadline)
                .foregroundStyle(Theme.textMuted)

            HStack(alignment: .top, spacing: 0) {
                speedColumn(title: "下行 ↓", value: SpeedFormatter.format(monitor.downSpeed, unit: monitor.unit), color: Theme.teal)
                Rectangle()
                    .fill(Theme.line)
                    .frame(width: 1)
                    .padding(.horizontal, 16)
                speedColumn(title: "上行 ↑", value: SpeedFormatter.format(monitor.upSpeed, unit: monitor.unit), color: Theme.mint)
            }
            .padding(.top, 18)
        }
    }

    private func speedColumn(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.textMuted)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var islandBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.liveActivityOn ? Theme.teal : Theme.amber)
                    .frame(width: 8, height: 8)
                Text(monitor.liveActivityOn ? "灵动岛网速已开启" : "灵动岛未开启")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.text)
            }
            Text(
                monitor.liveActivityOn
                    ? (monitor.keepAliveEnabled
                        ? "已开后台保活：切走后按间隔继续刷岛（更耗电）。从多任务杀掉 App 仍会停。"
                        : "未开后台保活：系统挂起后刘海会冻住，需再打开 App。")
                    : "开始监控后会尝试打开灵动岛。请在系统设置 → 网速 中允许实时活动。"
            )
            .font(.caption)
            .foregroundStyle(Theme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(monitor.liveActivityOn ? Theme.teal.opacity(0.14) : Theme.amber.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(monitor.liveActivityOn ? Theme.teal.opacity(0.35) : Theme.amber.opacity(0.28), lineWidth: 1)
        )
    }

    private var chartPeak: Double {
        max(monitor.history.map(\.down).max() ?? 0, monitor.history.map(\.up).max() ?? 0)
    }

    /// Flatten + sort so Charts never stitches 下行/上行 into one backwards path.
    private var chartPoints: [ChartPoint] {
        monitor.history
            .sorted { $0.at < $1.at }
            .flatMap { sample in
                [
                    ChartPoint(at: sample.at, value: sample.down, series: "下行"),
                    ChartPoint(at: sample.at, value: sample.up, series: "上行")
                ]
            }
    }

    private var chartTimeDomain: ClosedRange<Date> {
        let times = monitor.history.map(\.at).sorted()
        guard let first = times.first, let last = times.last else {
            let now = Date()
            return now.addingTimeInterval(-60)...now
        }
        if first == last {
            return first.addingTimeInterval(-1)...last.addingTimeInterval(1)
        }
        return first...last
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(monitor.historyWindowLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("峰值 \(SpeedFormatter.format(chartPeak, unit: monitor.unit))")
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
            }

            Chart {
                ForEach(chartPoints) { point in
                    LineMark(
                        x: .value("时间", point.at),
                        y: .value("速率", point.value),
                        series: .value("方向", point.series)
                    )
                    .foregroundStyle(by: .value("方向", point.series))
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartForegroundStyleScale([
                "下行": Theme.teal,
                "上行": Theme.mint
            ])
            .chartLegend(position: .top, alignment: .trailing)
            .chartXScale(domain: chartTimeDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Theme.line.opacity(0.6))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.minute().second())
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Theme.line)
                    AxisValueLabel {
                        if let bytes = value.as(Double.self) {
                            Text(SpeedFormatter.compact(bytes))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...max(chartPeak, 1024))
            .frame(height: 168)
            .padding(.top, 4)
            .padding(.trailing, 8)
            .padding(.bottom, 4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )

            if monitor.history.count < 2 {
                Text("采样中…打开网页或刷视频即可看到曲线")
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
            }
        }
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(monitor.networkLabel)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.mint.opacity(0.12)))
                    .foregroundStyle(Theme.text)
                Text(monitor.networkDetail)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("累计下行")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                    Text(SpeedFormatter.dataSize(monitor.totalDown))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Text("累计上行")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                    Text(SpeedFormatter.dataSize(monitor.totalUp))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private var intervalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("灵动岛间隔")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(monitor.intervalLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textFaint)
            }
            Text("按此秒数对流量取平均，再刷新灵动岛（App 内仍实时）")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                ForEach(TrafficMonitor.intervalOptions, id: \.self) { seconds in
                    let selected = monitor.sampleInterval == seconds
                    Button {
                        monitor.setSampleInterval(seconds)
                    } label: {
                        Text("\(Int(seconds))s")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(selected ? Theme.bgDeep : Theme.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selected ? Theme.teal : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(selected ? Color.clear : Theme.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Toggle(isOn: Binding(
                get: { monitor.keepAliveEnabled },
                set: { monitor.setKeepAliveEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("后台持续刷岛")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.text)
                    Text("保活进程，切走后仍按间隔更新灵动岛（更耗电；杀进程无效）")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                }
            }
            .tint(Theme.teal)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(monitor.isMonitoring ? "暂停监控" : "开始监控") {
                monitor.toggleMonitoring()
            }
            .buttonStyle(PrimaryButtonStyle(filled: !monitor.isMonitoring))

            Button(monitor.unit.toggleTitle) {
                monitor.toggleUnit()
            }
            .buttonStyle(PrimaryButtonStyle(filled: false))
        }
    }

    private var speedTestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("一键测速")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.text)
            Text("Cloudflare 公开节点 · 结果仅本机显示")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)

            HStack {
                metric("延迟", speedTest.result.pingMs.map { String(format: "%.0f ms", $0) } ?? "—")
                metric("下载", speedTest.result.downloadMbps.map { String(format: "%.1f Mbps", $0) } ?? "—")
                metric("上传", speedTest.result.uploadMbps.map { String(format: "%.1f Mbps", $0) } ?? "—")
            }

            if let error = speedTest.result.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.coral)
            }

            Button(speedTest.isBusy ? "停止" : (speedTest.phase == .done ? "再测一次" : "测一下真实带宽")) {
                speedTest.toggle()
            }
            .buttonStyle(PrimaryButtonStyle(filled: true))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.teal.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var debugLogCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("采样日志")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("tick #\(logger.tickCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textFaint)
            }
            HStack {
                Text("本地 \(logger.fileSizeLabel)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textMuted)
                Spacer()
                Button("清空") {
                    logger.clearFile()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.teal)
            }
            Text("Documents/Logs/netspeed.log · 上限 10MB 自动轮转")
                .font(.caption2)
                .foregroundStyle(Theme.textFaint)
            Text("原始 ↓\(SpeedFormatter.compact(monitor.rawDown))  ↑\(SpeedFormatter.compact(monitor.rawUp))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textMuted)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(logger.lines.suffix(12).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.textFaint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 140)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
    }
}

private struct ChartPoint: Identifiable {
    let id: String
    let at: Date
    let value: Double
    let series: String

    init(at: Date, value: Double, series: String) {
        self.at = at
        self.value = value
        self.series = series
        self.id = "\(series)-\(at.timeIntervalSince1970)"
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(filled ? Theme.bgDeep : Theme.text)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(filled ? Theme.teal : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.line, lineWidth: filled ? 0 : 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
