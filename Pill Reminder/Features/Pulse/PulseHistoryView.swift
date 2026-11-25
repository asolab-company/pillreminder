import Charts
import SwiftUI

struct PulseHistoryView: View {
    private enum Mode: String, CaseIterable { case readings = "Measurements", trends = "Trends" }
    let entries: [PulseMeasurementEntry]
    let onDelete: (PulseMeasurementEntry) -> Void
    @State private var mode = Mode.readings
    @State private var period = PulsePeriod.month
    @State private var anchor = Date.now
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(spacing: 0) {
            header
            historyContent
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.largeTitle.bold()).foregroundStyle(PulseStyle.primaryText)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !entries.isEmpty {
                    Menu {
                        ShareLink(item: PulseReport(entries: entries, format: .pdf), preview: SharePreview("Pulse history PDF")) {
                            Label("Share PDF", systemImage: "doc.richtext")
                        }
                        ShareLink(item: PulseReport(entries: entries, format: .csv), preview: SharePreview("Pulse history CSV")) {
                            Label("Share CSV", systemImage: "tablecells")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                    }
                    .tint(PulseStyle.accent).accessibilityLabel("Share pulse history")
                }
            }
            HStack(spacing: 3) {
                ForEach(Mode.allCases, id: \.self) { item in
                    Button { mode = item } label: {
                        Text(item.rawValue).font(.subheadline.bold())
                            .foregroundStyle(mode == item ? .white : PulseStyle.primaryText)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(mode == item ? PulseStyle.accent : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(mode == item ? .isSelected : [])
                    .accessibilityIdentifier("history.\(item.rawValue)")
                }
            }
            .padding(3)
            .background(PulseStyle.separator, in: Capsule())
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)

    }

    @ViewBuilder
    private var historyContent: some View {
        if mode == .readings {
            if entries.isEmpty {
                HistoryEmptyState(title: "Your first reading goes here", message: "Tap the heart below to measure your pulse.", symbol: "heart.text.square")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let days = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.measuredAt) }
                List {
                    if let last = entries.first {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Latest pulse", systemImage: "heart.fill").font(.subheadline.weight(.semibold))
                                .foregroundStyle(PulseStyle.accent)
                            BPMValue(value: last.bpm)
                            Text(last.measuredAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote).foregroundStyle(PulseStyle.secondary)
                        }
                        .padding(4).listRowBackground(PulseStyle.accentTint)
                    }
                    ForEach(days.keys.sorted(by: >), id: \.self) { day in
                        Section(day.formatted(date: .abbreviated, time: .omitted)) {
                            ForEach(days[day] ?? []) { entry in
                                HStack(spacing: 12) {
                                    Image(systemName: "waveform.path.ecg").foregroundStyle(PulseStyle.accent)
                                        .frame(width: 36, height: 36).background(PulseStyle.accentTint, in: Circle())
                                    Text("\(entry.bpm) bpm").font(.headline).foregroundStyle(PulseStyle.primaryText)
                                    Spacer()
                                    Text(entry.measuredAt, style: .time).font(.subheadline).foregroundStyle(PulseStyle.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .swipeActions { Button("Delete", role: .destructive) { onDelete(entry) } }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped).listSectionSpacing(12)
                .contentMargins(.top, 0, for: .scrollContent).scrollContentBackground(.hidden)
            }
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    ViewThatFits(in: .horizontal) {
                        periodButtons
                        ScrollView(.horizontal) { periodButtons }.scrollIndicators(.hidden)
                    }
                    let summary = PulseTrendSummary(entries: entries, period: period, anchor: anchor, calendar: calendar)
                    periodNavigation(summary.interval)
                    PulseTrendCard(summary: summary, period: period)
                        .id(summary.interval.start)
                    if let low = summary.lowest, let avg = summary.average, let high = summary.highest {
                        HStack(spacing: 8) {
                            statistic("Lowest", low)
                            statistic("Average", avg)
                            statistic("Highest", high)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
        }
    }

    private var periodButtons: some View {
        HStack(spacing: 6) {
            ForEach(PulsePeriod.allCases, id: \.self) { item in
                Button {
                    period = item
                    anchor = .now
                } label: {
                    Text(item.rawValue).font(.subheadline.weight(.semibold)).fixedSize()
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .padding(.horizontal, 7)
                        .background(period == item ? .white : .clear, in: Capsule())
                        .overlay { Capsule().strokeBorder(period == item ? PulseStyle.accent : PulseStyle.separator, lineWidth: 1) }
                }
                .buttonStyle(.plain).foregroundStyle(period == item ? PulseStyle.accent : PulseStyle.secondary)
                .accessibilityAddTraits(period == item ? .isSelected : [])
            }
        }
    }

    private func periodNavigation(_ interval: DateInterval) -> some View {
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end)!
        let title: String = switch period {
        case .year: interval.start.formatted(.dateTime.year())
        case .month: interval.start.formatted(.dateTime.month(.wide).year())
        default: (interval.start..<lastDay.addingTimeInterval(1)).formatted(.interval.day().month(.abbreviated).year())
        }
        return HStack {
            Button { anchor = period.previous(to: interval, calendar: calendar).start } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous period")
            .disabled(entries.last.map { $0.measuredAt >= interval.start } ?? true)
            Spacer()
            Text(title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
            Spacer()
            Button { anchor = interval.end } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next period").disabled(interval.end > .now)
        }
        .tint(PulseStyle.accent)
    }

    private func statistic(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(value)").font(.title2.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(PulseStyle.secondary)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

private struct PulseTrendCard: View {
    let summary: PulseTrendSummary
    let period: PulsePeriod
    @State private var selectedDate: Date?

    private var selected: PulseTrendSummary.Point? {
        guard let selectedDate else { return nil }
        return summary.points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let average = summary.average {
                Label(selected == nil ? "Average pulse" : (period == .year ? "Monthly average" : "Daily average"), systemImage: "waveform.path.ecg")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(PulseStyle.accent)
                BPMValue(value: selected?.bpm ?? average)
                if let point = selected {
                    Text(point.date, format: period == .year ? .dateTime.month(.wide).year() : .dateTime.month(.abbreviated).day().year())
                        .font(.footnote).foregroundStyle(PulseStyle.secondary)
                } else if let change = summary.change {
                    Text("\(change.formatted(.number.sign(strategy: .always()))) bpm vs. previous period")
                        .font(.footnote).foregroundStyle(PulseStyle.secondary)
                }
                chart
                    .frame(height: 154)
                Text("\(summary.count) \(summary.count == 1 ? "reading" : "readings") · \(period == .year ? "Monthly" : "Daily") averages")
                    .font(.caption).foregroundStyle(PulseStyle.secondary)
            } else {
                HistoryEmptyState(title: "No readings this period", message: "Your saved measurements will appear on this chart.", symbol: "chart.xyaxis.line")
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .foregroundStyle(PulseStyle.primaryText)
    }

    private var chart: some View {
        let bottom = max(0, (summary.points.map(\.bpm).min() ?? 60) - 8)
        let top = (summary.points.map(\.bpm).max() ?? 80) + 8
        return Chart(summary.points) { point in
            AreaMark(x: .value("Date", point.date), yStart: .value("Baseline", bottom), yEnd: .value("Pulse", point.bpm))
                .foregroundStyle(LinearGradient(colors: [PulseStyle.accent.opacity(0.19), .clear], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)
            LineMark(x: .value("Date", point.date), y: .value("Pulse", point.bpm))
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(PulseStyle.accent).accessibilityHidden(true)
            PointMark(x: .value("Date", point.date), y: .value("Pulse", point.bpm))
                .symbolSize(point.id == selected?.id ? 80 : 26)
                .foregroundStyle(PulseStyle.accent)
                .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue("\(point.bpm) beats per minute")
        }
        .chartXScale(domain: summary.interval.start...summary.interval.end.addingTimeInterval(-1))
        .chartYScale(domain: bottom...top)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisValueLabel(format: period == .year ? .dateTime.month(.abbreviated) : .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { AxisGridLine(); AxisValueLabel() } }
        .chartXSelection(value: $selectedDate)
    }
}

private struct BPMValue: View {
    let value: Int
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(value)").font(.system(size: 54, weight: .bold, design: .rounded)).monospacedDigit()
            Text("bpm").font(.headline).foregroundStyle(PulseStyle.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryEmptyState: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light))
                .foregroundStyle(PulseStyle.accent).frame(width: 72, height: 72)
                .background(PulseStyle.accentTint, in: Circle())
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(PulseStyle.primaryText)
            Text(message).font(.subheadline).foregroundStyle(PulseStyle.secondary)
        }
        .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 24).padding(.horizontal, 12)
    }
}
