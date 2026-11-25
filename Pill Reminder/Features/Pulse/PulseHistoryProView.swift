import Charts
import SwiftUI

struct PulseHistoryProView: View {
    let onViewPro: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.largeTitle.bold())
                .foregroundStyle(PulseStyle.primaryText)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HistoryTrendPreview()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your pulse over time")
                            .font(.title.bold())
                            .foregroundStyle(PulseStyle.primaryText)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("history.locked")

                        Text("With Pro, revisit your saved measurements and compare your pulse by week, month, or year.")
                            .font(.body)
                            .foregroundStyle(PulseStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(action: onViewPro) {
                            HStack(spacing: 8) {
                                Text("View Pro")
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PulsePrimaryButton())
                        .accessibilityHint("Shows subscription options")
                        .accessibilityIdentifier("history.viewPro")
                        .padding(.top, 11)
                    }
                    .padding(22)
                }
                .background(.white, in: RoundedRectangle(cornerRadius: 26))
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(PulseStyle.separator.opacity(0.65), lineWidth: 0.5) }
                .shadow(color: PulseStyle.primaryText.opacity(0.065), radius: 12, y: 5)
                .frame(maxWidth: 500)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.center, for: .alignment)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(PulseStyle.background)
    }
}

private struct HistoryTrendPreview: View {
    private let levels = [0.38, 0.57, 0.44, 0.76, 0.60, 0.68, 0.49]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(PulseStyle.accent)
                Text("Trend preview")
                    .foregroundStyle(PulseStyle.primaryText)
                Spacer(minLength: 8)
                Image(systemName: "lock.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulseStyle.secondary)
            }
            .font(.subheadline.weight(.semibold))

            Chart {
                ForEach(levels.indices, id: \.self) { day in
                    AreaMark(
                        x: .value("Day", day), yStart: .value("Baseline", 0.0),
                        yEnd: .value("Level", levels[day])
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(
                        colors: [PulseStyle.accent.opacity(0.24), PulseStyle.accent.opacity(0.01)],
                        startPoint: .top, endPoint: .bottom
                    ))

                    LineMark(x: .value("Day", day), y: .value("Level", levels[day]))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(PulseStyle.accent)
                }
                if let lastDay = levels.indices.last {
                    PointMark(x: .value("Day", lastDay), y: .value("Level", levels[lastDay]))
                        .symbol {
                            Circle()
                                .fill(PulseStyle.accent)
                                .frame(width: 10, height: 10)
                                .padding(3)
                                .background(.white, in: Circle())
                        }
                }
            }
            .chartXScale(domain: 0...(levels.count - 1), range: .plotDimension(startPadding: 8, endPadding: 8))
            .chartYScale(domain: 0...1)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: [0.2, 0.5, 0.8]) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.7, dash: [3, 5]))
                        .foregroundStyle(PulseStyle.secondary.opacity(0.28))
                }
            }
            .aspectRatio(2.6, contentMode: .fit)

            HStack {
                Text("Mon")
                Spacer()
                Text("Thu")
                Spacer()
                Text("Sun")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(PulseStyle.secondary)
        }
        .padding(22)
        .background(LinearGradient(
            colors: [PulseStyle.accentTint.opacity(0.9), PulseStyle.accentTint.opacity(0.25)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sample seven-day pulse trend")
    }
}
