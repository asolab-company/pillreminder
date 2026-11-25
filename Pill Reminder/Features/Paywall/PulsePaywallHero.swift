import SwiftUI

struct PulsePaywallHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let contentHeight: CGFloat
    let topInset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || scenePhase != .active)) { time in
                    Canvas { context, size in
                        let phase = reduceMotion ? 0.45 : time.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.55) / 1.55
                        let center = CGPoint(x: size.width * 0.5, y: topInset + contentHeight * 0.52)
                        let span = min(size.width * 0.34, contentHeight * 0.61)
                        for scale in [1.45, 2.10] {
                            let radius = span * (scale + phase * 0.16) / 2
                            let bounds = CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)
                            context.fill(Path(ellipseIn: bounds), with: .color(.white.opacity(0.115 - phase * 0.05)))
                        }
                        let beat = reduceMotion ? 0 : max(0, 1 - abs(phase - 0.31) * 8)
                        let side = span * (1 + beat * 0.045)
                        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                            CGPoint(x: center.x + (x - 0.5) * side, y: center.y + (y - 0.5) * side)
                        }
                        var heart = Path()
                        heart.move(to: point(0.5, 0.94))
                        heart.addCurve(to: point(0.04, 0.38), control1: point(0.37, 0.86), control2: point(0.04, 0.61))
                        heart.addCurve(to: point(0.5, 0.23), control1: point(0.03, 0.06), control2: point(0.35, 0.04))
                        heart.addCurve(to: point(0.96, 0.38), control1: point(0.66, 0.04), control2: point(0.98, 0.06))
                        heart.addCurve(to: point(0.5, 0.94), control1: point(0.96, 0.61), control2: point(0.65, 0.85))
                        let stroke = StrokeStyle(lineWidth: max(2.2, side * 0.026), lineCap: .round, lineJoin: .round)
                        context.stroke(heart, with: .color(.white), style: stroke)
                        let y = point(0, 0.49).y
                        var trace = Path()
                        trace.move(to: CGPoint(x: 0, y: y))
                        for (x, v) in [(0.20,0.49), (0.30,0.25), (0.41,0.80), (0.54,0.08), (0.67,0.63), (0.76,0.49)] {
                            trace.addLine(to: point(x, v))
                        }
                        trace.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(trace, with: .linearGradient(Gradient(colors: [.white.opacity(0.18), .white, .white, .white.opacity(0.18)]),
                            startPoint: CGPoint(x: 0, y: y), endPoint: CGPoint(x: size.width, y: y)), style: stroke)
                    }
                }
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("7-day trend").font(.caption.weight(.semibold))
                            Canvas { context, size in
                                var line = Path()
                                let values = [0.22, 0.39, 0.16, 0.48, 0.55, 0.72, 0.82]
                                for (i, value) in values.enumerated() {
                                    let p = CGPoint(x: CGFloat(i) / CGFloat(values.count - 1) * size.width, y: value * size.height)
                                    if i == 0 { line.move(to: p) } else { line.addLine(to: p) }
                                }
                                context.stroke(line, with: .color(PulseStyle.accent), style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
                            }.frame(width: min(w * 0.19, 84), height: 17)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 15))
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Resting pulse").font(.caption.weight(.semibold))
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("62").font(.title2.bold())
                                Text("bpm").font(.caption.bold())
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 15))
                    }
                }
                .padding(.horizontal, max(15, w * 0.047)).padding(.vertical, max(12, contentHeight * 0.075))
                .padding(.top, topInset)
                .foregroundStyle(PulseStyle.primaryText)
                .dynamicTypeSize(...DynamicTypeSize.large)
            }
        }
        .frame(height: contentHeight + topInset)
        .background {
            LinearGradient(colors: [Color(hex: "FF633E"), Color(hex: "F21B39"), Color(hex: "D90037")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 34, bottomTrailingRadius: 34))
        .accessibilityHidden(true)
    }
}
