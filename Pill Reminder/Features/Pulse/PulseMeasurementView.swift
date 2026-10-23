import AVFoundation
import SwiftUI
import UIKit
import Combine

struct PulseMeasurementEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let bpm: Int
    let measuredAt: Date

    init(id: UUID = UUID(), bpm: Int, measuredAt: Date = Date()) {
        self.id = id
        self.bpm = bpm
        self.measuredAt = measuredAt
    }

    var category: PulseMeasurementCategory {
        PulseMeasurementCategory(bpm: bpm)
    }
}

enum PulseMeasurementCategory: String, Codable {
    case low = "Low"
    case resting = "Resting"
    case normal = "Normal"
    case slightlyElevated = "Slightly Elevated"
    case high = "High"

    init(bpm: Int) {
        switch bpm {
        case ..<65:
            self = .low
        case 65...75:
            self = .resting
        case 76...89:
            self = .normal
        case 90...99:
            self = .slightlyElevated
        default:
            self = .high
        }
    }

    var color: Color {
        switch self {
        case .low:
            return Color(hex: "00C8FF")
        case .resting:
            return Color(hex: "26C9C4")
        case .normal:
            return Color(hex: "00A524")
        case .slightlyElevated:
            return Color(hex: "FFBB00")
        case .high:
            return Color(hex: "FF0004")
        }
    }
}

enum PulseMeasurementStore {
    private static let storageKey = "pulseMeasurements"

    static func load() -> [PulseMeasurementEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([PulseMeasurementEntry].self, from: data)
        else {
            return []
        }

        return entries.sorted { $0.measuredAt > $1.measuredAt }
    }

    static func save(_ entries: [PulseMeasurementEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func add(_ entry: PulseMeasurementEntry) -> [PulseMeasurementEntry] {
        let updated = ([entry] + load()).sorted { $0.measuredAt > $1.measuredAt }
        save(updated)
        return updated
    }

    static func delete(_ entry: PulseMeasurementEntry) -> [PulseMeasurementEntry] {
        let updated = load().filter { $0.id != entry.id }
        save(updated)
        return updated
    }
}

struct PulseMeasurementView: View {
    @Environment(\.deviceSize) private var deviceSize
    let entries: [PulseMeasurementEntry]
    let onStartMeasurement: () -> Void
    let onDelete: (PulseMeasurementEntry) -> Void
    @State private var swipedEntryID: UUID?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "F2F2F2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if entries.isEmpty {
                    emptyState
                } else {
                    measurementsList
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pulse Measurement")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color(hex: "222222"))
                .padding(.top, 10)

            Text("Track your heart rate quickly and easily using your device.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(hex: "6A7282"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            Button(action: onStartMeasurement) {
                HStack {
                    Spacer()
                    Text("Start Measurement")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Image(systemName: "heart")
                        .font(.system(size: 26, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(height: 48)
                .padding(.horizontal, 26)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FF2450"),
                                    Color(hex: "FF002B"),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(
                            color: Color(hex: "FF002B").opacity(0.25),
                            radius: 4,
                            y: 4
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 28)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(hex: "AEB5BC"))
                    .frame(width: 24, height: 24)
                    .padding(.top, 12)

                Text("This measurement is for informational purposes only and provides approximate results.\nIt is not intended for medical use and should not be relied upon for diagnosis or treatment.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "AEB5BC"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            .padding(.top, 12)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 260)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color(hex: "E6E6E6"))
            .overlay {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 24,
                    bottomTrailingRadius: 24,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .stroke(Color.white, lineWidth: 1)
            }
            .shadow(color: Color(hex: "CACACA").opacity(0.25), radius: 8, y: 4)
            .ignoresSafeArea(edges: .top)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {

                Image("app_ic_empty_clock")
                    .font(.system(size: emptyStateImageSize * 0.62, weight: .ultraLight))
                    .foregroundStyle(Color(hex: "D9DDE3"))

            Text("No measurements yet")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(hex: "99A1AF"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }

    private var measurementsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    if !deviceSize.isExtraSmallDevice {
                        Spacer()
                    }

                        Image("app_ic_idea")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)

                    Text("Swipe left to delete Measurement")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "99A1AF"))

                    if !deviceSize.isExtraSmallDevice {
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 6)

                ForEach(entries) { entry in
                    PulseMeasurementSwipeRow(
                        entry: entry,
                        isOpen: Binding(
                            get: { swipedEntryID == entry.id },
                            set: { isOpen in
                                swipedEntryID = isOpen ? entry.id : nil
                            }
                        ),
                        onDelete: {
                            swipedEntryID = nil
                            onDelete(entry)
                        }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 140)
        }
    }

    private var emptyStateImageSize: CGFloat {
        if deviceSize.isExtraSmallDevice {
            return 120
        }

        if deviceSize.isSmallDevice {
            return 136
        }

        return 146
    }
}

private struct PulseMeasurementSwipeRow: View {
    let entry: PulseMeasurementEntry
    @Binding var isOpen: Bool
    let onDelete: () -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var isDeleting = false

    private let deleteWidth: CGFloat = 86
    private let deleteAnimationDuration: TimeInterval = 0.24

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                Button {
                    triggerDelete(width: proxy.size.width)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: deleteWidth, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(hex: "FF002B"))
                        )
                }
                .buttonStyle(.plain)

                PulseMeasurementRow(entry: entry)
                    .offset(x: rowOffset)
                    .contentShape(Rectangle())
                    .overlay {
                        HorizontalSwipeReader { translation in
                            guard !isDeleting else { return }

                            let baseOffset = isOpen ? -deleteWidth : 0
                            dragOffset = min(0, max(-deleteWidth * 1.35, baseOffset + translation))
                        } onEnded: { translation, velocity in
                            guard !isDeleting else { return }

                            let predictedOffset = rowOffset + translation * 0.18 + velocity * 0.04
                            if predictedOffset < -deleteWidth * 1.15 {
                                triggerDelete(width: proxy.size.width)
                            } else {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    isOpen = rowOffset < -deleteWidth * 0.45
                                    dragOffset = 0
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        guard isOpen, !isDeleting else { return }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            isOpen = false
                        }
                    }
                    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isOpen)
            }
            .allowsHitTesting(!isDeleting)
        }
        .frame(height: 80)
        .clipped()
    }

    private var rowOffset: CGFloat {
        if dragOffset != 0 {
            return dragOffset
        }

        return isOpen ? -deleteWidth : 0
    }

    private func triggerDelete(width: CGFloat) {
        guard !isDeleting else { return }

        withAnimation(.easeInOut(duration: deleteAnimationDuration)) {
            isDeleting = true
            isOpen = false
            dragOffset = -(width + deleteWidth + 24)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + deleteAnimationDuration) {
            onDelete()
        }
    }
}

private struct HorizontalSwipeReader: UIViewRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let recognizer = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat, CGFloat) -> Void

        init(
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat, CGFloat) -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)
            let velocity = recognizer.velocity(in: recognizer.view)

            switch recognizer.state {
            case .changed:
                onChanged(translation.x)
            case .ended, .cancelled, .failed:
                onEnded(translation.x, velocity.x)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }

            let velocity = pan.velocity(in: pan.view)
            let horizontal = abs(velocity.x)
            let vertical = abs(velocity.y)
            return horizontal > 90 && horizontal > vertical * 1.45
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private struct PulseMeasurementRow: View {
    let entry: PulseMeasurementEntry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Self.dateFormatter.string(from: entry.measuredAt))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "222222"))

                Text(Self.timeFormatter.string(from: entry.measuredAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "99A1AF"))
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(entry.bpm) BPM")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: "222222"))

                Text(entry.category.rawValue)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 14)
                    .frame(height: 24)
                    .background(
                        Capsule()
                            .fill(entry.category.color.opacity(0.82))
                    )
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 80)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(hex: "CACACA").opacity(0.25), radius: 8, y: 4)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

struct PulseReaderView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reader = PulseCameraPulseReader()
    let onCompleted: (PulseMeasurementEntry) -> Void

    var body: some View {
        PulseReaderContent(
            snapshot: PulseReaderSnapshot(
                phase: reader.phase,
                progress: reader.progress,
                estimatedBPM: reader.estimatedBPM,
                signalQuality: reader.signalQuality,
                statusText: reader.statusText,
                title: reader.title,
                message: reader.message
            ),
            onBack: {
                reader.stop()
                dismiss()
            },
            onAction: {
                if reader.phase == .permissionDenied,
                   let settingsURL = URL(string: UIApplication.openSettingsURLString)
                {
                    UIApplication.shared.open(settingsURL)
                } else {
                    reader.start()
                }
            },
            onMenu: {
                reader.stop()
                dismiss()
            }
        )
        .onAppear {
            reader.start()
        }
        .onDisappear {
            reader.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                reader.stop()
            } else if phase == .active,
                      reader.phase == .preparing || reader.phase == .measuring || reader.phase == .permissionDenied {
                reader.start()
            }
        }
        .onChange(of: reader.completedBPM) { _, bpm in
            guard let bpm else { return }
            onCompleted(PulseMeasurementEntry(bpm: bpm))
        }
    }
}

private struct PulseReaderSnapshot {
    let phase: PulseReaderPhase
    let progress: Double
    let estimatedBPM: Int?
    let signalQuality: Double
    let statusText: String
    let title: String
    let message: String

    var actionTitle: String {
        phase == .permissionDenied ? "Open Settings" : "Restart Measurement"
    }
}

private struct PulseReaderContent: View {
    let snapshot: PulseReaderSnapshot
    let onBack: () -> Void
    let onAction: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "F2F2F2")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color(hex: "6A7282"))
                            .frame(width: 40, height: 40)
                            .background {
                                Circle()
                                    .fill(Color.white.opacity(0.5))
                                    .overlay {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 1)
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to Pulse")

                    Spacer()
                }
                .padding(.horizontal, 19)
                .padding(.top, 16)

                Spacer(minLength: 88)

                pulseIcon

                Text(headerTitle)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color(hex: "222222"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                if let category = completedCategory {
                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 14)
                        .frame(height: 24)
                        .background(
                            Capsule()
                                .fill(category.color.opacity(0.82))
                        )
                        .padding(.top, 14)
                }

                Text(headerSubtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "222222"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 26)
                    .padding(.top, snapshot.phase == .completed ? 20 : 8)

                if snapshot.phase == .completed {
                    Text("This result is approximate and provided for\ninformational purposes only.\nIt is not intended for medical use or diagnosis.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "99A1AF"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 34)
                        .padding(.top, 46)
                }

                Spacer()

                statusContent
                    .padding(.bottom, hasFooterActions ? 16 : 118)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            footerActions
                .padding(.bottom, 14)
        }
    }

    private var statusContent: some View {
        VStack(spacing: 8) {
            if snapshot.phase != .failed && snapshot.phase != .completed {
                Text(snapshot.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(hex: "222222"))

                Text(snapshot.message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: "222222"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 300)

                PulseSignalStatusView(
                    text: snapshot.statusText,
                    quality: snapshot.phase == .measuring ? snapshot.signalQuality : nil
                )
                .padding(.top, 8)
            }

            if snapshot.phase == .measuring {
                HeartbeatProgressView(progress: snapshot.progress)
                    .padding(.horizontal, 24)
                    .padding(.top, 22)

                Text("\(Int(snapshot.progress * 100))%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "99A1AF"))

                Text(snapshot.estimatedBPM.map { "~\($0) BPM" } ?? "~000 BPM")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "FF002B"))
                    .opacity(snapshot.estimatedBPM == nil ? 0 : 1)
                    .frame(height: 22)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var footerActions: some View {
        if hasFooterActions {
            VStack(spacing: 6) {
                measurementActionButton
                    .padding(.horizontal, 24)

                if snapshot.phase == .failed || snapshot.phase == .completed {
                    Button("Go to Menu", action: onMenu)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "FF002B"))
                        .frame(height: 48)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                }
            }
        }
    }

    private var measurementActionButton: some View {
        Button(action: onAction) {
            HStack {
                Spacer()
                Text(snapshot.actionTitle)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Image(systemName: "heart")
                    .font(.system(size: 26, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(height: 48)
            .padding(.horizontal, 26)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "FF2450"),
                                Color(hex: "FF002B"),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: Color(hex: "FF002B").opacity(0.25),
                        radius: 4,
                        y: 4
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var pulseIcon: some View {
        Image(snapshot.phase == .failed ? "app_ic_alert" : "app_ic_pulse")
            .resizable()
            .scaledToFit()
            .frame(width: 134, height: 134)
    }

    private var hasFooterActions: Bool {
        snapshot.phase == .failed
            || snapshot.phase == .completed
            || snapshot.phase == .permissionDenied
    }

    private var headerTitle: String {
        if snapshot.phase == .failed || snapshot.phase == .completed {
            return snapshot.title
        }

        return "Measure Your Pulse"
    }

    private var bottomContentPadding: CGFloat {
        if snapshot.phase == .failed
            || snapshot.phase == .completed
            || snapshot.phase == .permissionDenied
        {
            return 30
        }

        return 88
    }

    private var headerSubtitle: String {
        if snapshot.phase == .failed {
            return snapshot.message
        }

        if snapshot.phase == .completed {
            return "Your approximate pulse estimate has been saved. Repeat the measurement if you want to compare readings."
        }

        return "Cover the rear 1x camera next to the flash and stay still.\nHold still while we check the signal and estimate your pulse."
    }

    private var completedCategory: PulseMeasurementCategory? {
        guard snapshot.phase == .completed,
              let bpm = snapshot.estimatedBPM
        else {
            return nil
        }

        return PulseMeasurementCategory(bpm: bpm)
    }
}

private struct HeartbeatProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            HeartbeatWaveShape()
                .stroke(
                    Color(hex: "99A1AF").opacity(0.55),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )

            HeartbeatWaveShape()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    Color(hex: "FF002B"),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color(hex: "FF002B").opacity(0.24), radius: 4, y: 2)
                .animation(.easeInOut(duration: 0.18), value: clampedProgress)
        }
        .frame(height: 42)
    }

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }
}

private struct PulseSignalStatusView: View {
    let text: String
    let quality: Double?

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 7, height: 7)

            Text(statusText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "6A7282"))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.62))
        )
    }

    private var statusText: String {
        guard let quality else { return text }
        return "\(text) • Signal \(Int((quality * 100).rounded()))%"
    }

    private var indicatorColor: Color {
        guard let quality else {
            return text == "Cover rear camera" ? Color(hex: "99A1AF") : Color(hex: "00A524")
        }

        if quality >= 0.72 {
            return Color(hex: "00A524")
        }

        if quality >= 0.52 {
            return Color(hex: "FFBB00")
        }

        return Color(hex: "FF002B")
    }
}

nonisolated private struct HeartbeatWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pattern: [(x: CGFloat, y: CGFloat)] = [
            (0.00, 0.00),
            (0.15, 0.00),
            (0.20, -0.12),
            (0.25, 0.00),
            (0.35, 0.00),
            (0.42, -0.82),
            (0.50, 0.88),
            (0.58, -0.24),
            (0.68, 0.00),
            (1.00, 0.00),
        ]
        let beatCount = max(3, Int(rect.width / 92))
        let beatWidth = rect.width / CGFloat(beatCount)
        let midY = rect.midY
        let amplitude = rect.height * 0.38
        var path = Path()
        var didMove = false

        for beatIndex in 0..<beatCount {
            let originX = rect.minX + CGFloat(beatIndex) * beatWidth

            for point in pattern {
                let x = originX + point.x * beatWidth
                let y = midY + point.y * amplitude

                if didMove {
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    path.move(to: CGPoint(x: x, y: y))
                    didMove = true
                }
            }
        }

        return path
    }
}

nonisolated enum PulseReaderPhase {
    case idle
    case preparing
    case measuring
    case completed
    case failed
    case permissionDenied
}

nonisolated private struct PulseFrameMetrics {
    let red: Double
    let green: Double
    let blue: Double

    var signalValue: Double {
        red / max(red + green + blue, 1)
    }

    var brightness: Double {
        (red + green + blue) / 3
    }

    var hasFingerCoverage: Bool {
        red > 52 && red > green * 0.96 && red > blue * 1.02
    }
}

nonisolated final class PulseCameraPulseReader: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    @MainActor @Published private(set) var phase: PulseReaderPhase = .idle
    @MainActor @Published private(set) var progress: Double = 0
    @MainActor @Published private(set) var estimatedBPM: Int?
    @MainActor @Published private(set) var signalQuality: Double = 0
    @MainActor @Published private(set) var statusText = "Cover rear camera"
    @MainActor @Published private(set) var completedBPM: Int?
    @MainActor @Published private(set) var title = "Preparing"
    @MainActor @Published private(set) var message = "Get ready…\nCover the rear camera next to the flash."

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "pulse.camera.session")
    private let stabilizationDuration: TimeInterval = 1.5
    private let measurementDuration: TimeInterval = 12
    private let maxMeasurementDuration: TimeInterval = 20
    private let minimumDisplayQuality = 0.45
    private let minimumFinalQuality = 0.65
    private var videoDevice: AVCaptureDevice?
    private var samples: [PulseSignalSample] = []
    private var measurementStartedAt: TimeInterval?
    private var estimateHistory: [PulseEstimate] = []
    private var lastEstimateRecordedAt: TimeInterval = 0
    private var lastUIUpdateAt: TimeInterval = 0
    private var lastFrameTime: TimeInterval?
    private var lastAnalysisAt: TimeInterval = 0
    private var shouldCapture = false
    private var sessionRequestGeneration: UInt64 = 0
    private var activeCaptureID: UUID?
    @MainActor private var permissionTask: Task<Void, Never>?
    @MainActor private var requestGeneration: UInt64 = 0
    private var isRunning = false
    private var didComplete = false
    private var fingerCoveredFrameCount = 0
    private var fingerMissingFrameCount = 0
    private let requiredFingerFrameCount = 4
    private let toleratedMissingFrameCount = 3

    @MainActor
    func start() {
        permissionTask?.cancel()
        requestGeneration &+= 1
        let generation = requestGeneration
        resetState()
        sessionQueue.async { [weak self] in
            self?.shouldCapture = true
            self?.sessionRequestGeneration = generation
        }

        permissionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.requestGeneration == generation {
                    self.permissionTask = nil
                }
            }
            let granted: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                granted = true
            case .notDetermined:
                granted = await AVCaptureDevice.requestAccess(for: .video)
            case .denied, .restricted:
                granted = false
            @unknown default:
                granted = false
            }
            guard !Task.isCancelled, self.requestGeneration == generation else { return }
            guard granted else {
                self.updatePhase(
                    .permissionDenied,
                    title: "Camera Access Needed",
                    message: "Allow camera access to measure your pulse.",
                    generation: generation
                )
                return
            }
            guard UIApplication.shared.applicationState == .active else { return }
            self.configureAndStart(generation: generation)
        }
    }

    @MainActor
    func stop() {
        requestGeneration &+= 1
        permissionTask?.cancel()
        permissionTask = nil
        sessionQueue.async { [weak self] in
            self?.shouldCapture = false
            self?.stopCapture()
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        guard isRunning,
              !didComplete,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let metrics = Self.averageMetrics(from: pixelBuffer)
        else {
            return
        }

        let now = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        guard now.isFinite else { return }
        if let lastFrameTime {
            guard now > lastFrameTime else { return }
            if now - lastFrameTime > 0.25 {
                resetMeasurementBuffer()
            }
        }
        lastFrameTime = now

        if metrics.hasFingerCoverage {
            fingerCoveredFrameCount += 1
            fingerMissingFrameCount = 0
        } else {
            fingerCoveredFrameCount = 0
            fingerMissingFrameCount += 1

            if measurementStartedAt != nil
                && fingerMissingFrameCount <= toleratedMissingFrameCount
            {
                return
            }

            resetMeasurementBuffer()
            publishThrottled(
                at: now,
                phase: .preparing,
                progress: 0,
                estimatedBPM: nil,
                signalQuality: 0,
                statusText: "Cover rear camera",
                title: "Preparing",
                message: "Get ready…\nCover the rear camera next to the flash."
            )
            return
        }

        guard measurementStartedAt != nil
            || fingerCoveredFrameCount >= requiredFingerFrameCount
        else {
            publishThrottled(
                at: now,
                phase: .preparing,
                progress: 0,
                estimatedBPM: nil,
                signalQuality: 0,
                statusText: "Cover rear camera",
                title: "Preparing",
                message: "Get ready…\nCover the rear camera next to the flash."
            )
            return
        }

        if measurementStartedAt == nil {
            measurementStartedAt = now
            samples.removeAll(keepingCapacity: true)
        }

        guard let measurementStartedAt else { return }

        let elapsed = now - measurementStartedAt
        let measuringElapsed = max(0, elapsed - stabilizationDuration)
        samples.append(
            PulseSignalSample(
                time: elapsed,
                value: metrics.signalValue,
                brightness: metrics.brightness
            )
        )
        samples.removeAll { elapsed - $0.time > stabilizationDuration + maxMeasurementDuration + 1.5 }

        guard now - lastAnalysisAt >= 0.5 else { return }
        lastAnalysisAt = now

        let peakEstimate = measuringElapsed > 3.5
            ? PulseSignalAnalyzer.estimatePulse(from: samples, stabilizationDuration: stabilizationDuration)
            : nil
        let frequencyEstimate = measuringElapsed > 6
            ? PulseSignalAnalyzer.frequencyEstimate(from: samples, stabilizationDuration: stabilizationDuration)
            : nil
        let estimate = PulseSignalAnalyzer.combinePulseEstimates(peakEstimate, frequencyEstimate)
        if let estimate, now - lastEstimateRecordedAt > 0.65 {
            estimateHistory.append(estimate)
            if estimateHistory.count > 24 {
                estimateHistory.removeFirst(estimateHistory.count - 24)
            }
            lastEstimateRecordedAt = now
        }

        let displayEstimate = PulseSignalAnalyzer.aggregateEstimate(from: Array(estimateHistory.suffix(6)) + [estimate].compactMap { $0 })
        let displayBPM = estimate != nil && (displayEstimate?.quality ?? 0) >= minimumDisplayQuality
            ? displayEstimate?.bpm : nil
        let signalQuality = estimate?.quality ?? PulseSignalAnalyzer.basicSignalQuality(
            from: samples,
            stabilizationDuration: stabilizationDuration
        )
        let nextPhase: PulseReaderPhase = elapsed < stabilizationDuration ? .preparing : .measuring
        publishThrottled(
            at: now,
            phase: nextPhase,
            progress: min(measuringElapsed / measurementDuration, 0.95),
            estimatedBPM: displayBPM,
            signalQuality: signalQuality,
            statusText: nextPhase == .preparing ? "Finger detected" : (estimate == nil ? "Improving signal" : "Hold still"),
            title: nextPhase == .preparing ? "Preparing" : "Measuring",
            message: nextPhase == .preparing
                ? "Finger detected.\nHold still while the signal stabilizes."
                : "Measuring your pulse...\nPlease stay still."
        )

        guard measuringElapsed >= measurementDuration else { return }

        let finalEstimate = PulseSignalAnalyzer.reliableFinalEstimate(
            from: Array(estimateHistory.suffix(6))
        )

        guard let estimate, estimate.quality >= minimumFinalQuality,
              let finalEstimate, finalEstimate.quality >= minimumFinalQuality,
              Double(abs(estimate.bpm - finalEstimate.bpm)) <= max(5, Double(finalEstimate.bpm) * 0.06)
        else {
            if measuringElapsed < maxMeasurementDuration && signalQuality >= 0.16 {
                publishThrottled(
                    at: now,
                    phase: .measuring,
                    progress: min(measuringElapsed / measurementDuration, 0.95),
                    estimatedBPM: displayBPM,
                    signalQuality: signalQuality,
                    statusText: "Hold still",
                    title: "Measuring",
                    message: "Almost there...\nKeep your finger steady on the camera."
                )
                return
            }

            updatePhase(
                .failed,
                title: "Error",
                message: "We couldn’t detect your pulse.\nMake sure your finger fully covers the camera and try again.",
                generation: sessionRequestGeneration
            )
            stopCapture()
            return
        }

        didComplete = true
        let generation = sessionRequestGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.requestGeneration == generation else { return }
            self.phase = .completed
            self.progress = 1
            self.estimatedBPM = finalEstimate.bpm
            self.signalQuality = finalEstimate.quality
            self.statusText = "Good signal"
            self.completedBPM = finalEstimate.bpm
            self.title = "\(finalEstimate.bpm) BPM"
            self.message = "Measurement saved."
        }
        stopCapture()
    }

    @MainActor
    private func resetState() {
        phase = .preparing
        progress = 0
        estimatedBPM = nil
        signalQuality = 0
        statusText = "Cover rear camera"
        completedBPM = nil
        title = "Preparing"
        message = "Get ready…\nCover the rear camera next to the flash."
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.stopCapture()
            self.resetMeasurementBuffer()
            self.lastFrameTime = nil
            self.lastUIUpdateAt = 0
            self.didComplete = false
            self.fingerMissingFrameCount = 0
        }
    }

    private func configureAndStart(generation: UInt64) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.shouldCapture, self.sessionRequestGeneration == generation, !self.isRunning else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .low

            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }

            guard let device = Self.makeRearPulseCamera() else {
                self.session.commitConfiguration()
                self.updatePhase(
                    .failed,
                    title: "Camera Unavailable",
                    message: "This device doesn't have a supported rear camera.",
                    generation: generation
                )
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    self.updatePhase(
                        .failed,
                        title: "Camera Unavailable",
                        message: "Unable to start the camera.",
                        generation: generation
                    )
                    return
                }
                self.session.addInput(input)
                self.videoDevice = device
            } catch {
                self.session.commitConfiguration()
                self.updatePhase(
                    .failed,
                    title: "Camera Unavailable",
                    message: "Unable to start the camera.",
                    generation: generation
                )
                return
            }

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.setSampleBufferDelegate(self, queue: self.sessionQueue)

            guard self.session.canAddOutput(output) else {
                self.session.commitConfiguration()
                self.updatePhase(
                    .failed,
                    title: "Camera Unavailable",
                    message: "Unable to read camera frames.",
                    generation: generation
                )
                return
            }

            self.session.addOutput(output)
            self.session.commitConfiguration()
            self.session.startRunning()
            self.isRunning = self.session.isRunning
            guard self.isRunning else {
                self.updatePhase(.failed, title: "Camera Unavailable", message: "Unable to start the camera.", generation: generation)
                return
            }
            let captureID = UUID()
            self.activeCaptureID = captureID
            self.enableTorch()
            self.sessionQueue.asyncAfter(deadline: .now() + 45) { [weak self] in
                guard let self, self.isRunning, self.activeCaptureID == captureID else { return }
                self.stopCapture()
                self.updatePhase(
                    .failed,
                    title: "Measurement Timed Out",
                    message: "We couldn’t get a stable signal. Adjust your finger and try again.",
                    generation: generation
                )
            }
        }
    }

    private func enableTorch(retryCount: Int = 3) {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        guard isRunning,
              let videoDevice,
              videoDevice.hasTorch
        else {
            return
        }

        do {
            try videoDevice.lockForConfiguration()
            defer {
                videoDevice.unlockForConfiguration()
            }

            guard videoDevice.isTorchAvailable else {
                retryTorchIfNeeded(retryCount)
                return
            }

            try videoDevice.setTorchModeOn(level: min(AVCaptureDevice.maxAvailableTorchLevel, 0.9))
        } catch {
            retryTorchIfNeeded(retryCount)
        }
    }

    private func retryTorchIfNeeded(_ retryCount: Int) {
        guard retryCount > 0 else { return }

        sessionQueue.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.enableTorch(retryCount: retryCount - 1)
        }
    }

    private func resetMeasurementBuffer() {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        measurementStartedAt = nil
        estimateHistory.removeAll(keepingCapacity: true)
        lastEstimateRecordedAt = 0
        lastAnalysisAt = 0
        samples.removeAll(keepingCapacity: true)
        fingerCoveredFrameCount = 0
    }

    private func stopCapture() {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        activeCaptureID = nil
        shouldCapture = false
        isRunning = false
        if session.isRunning {
            session.stopRunning()
        }
        if let videoDevice, videoDevice.hasTorch {
            do {
                try videoDevice.lockForConfiguration()
                defer { videoDevice.unlockForConfiguration() }
                videoDevice.torchMode = .off
            } catch {}
        }
    }

    private func updatePhase(
        _ phase: PulseReaderPhase,
        title: String,
        message: String,
        generation: UInt64
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.requestGeneration == generation else { return }
            self.phase = phase
            self.progress = 0
            self.estimatedBPM = nil
            self.signalQuality = 0
            self.statusText = phase == .permissionDenied ? "Camera access needed" : "Poor signal"
            self.title = title
            self.message = message
        }
    }

    private func publishThrottled(
        at now: TimeInterval,
        phase: PulseReaderPhase,
        progress: Double,
        estimatedBPM: Int?,
        signalQuality: Double,
        statusText: String,
        title: String,
        message: String
    ) {
        guard now - lastUIUpdateAt > 0.12 else { return }
        lastUIUpdateAt = now

        let generation = sessionRequestGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.requestGeneration == generation else { return }
            self.phase = phase
            self.progress = progress
            self.estimatedBPM = estimatedBPM
            self.signalQuality = signalQuality
            self.statusText = statusText
            self.title = title
            self.message = message
        }
    }

    private static func makeRearPulseCamera() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )

        return discovery.devices.first(where: \.hasTorch)
            ?? discovery.devices.first
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    private static func averageMetrics(from pixelBuffer: CVPixelBuffer) -> PulseFrameMetrics? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        let step = 12
        let startX = width / 4
        let endX = width - startX
        let startY = height / 4
        let endY = height - startY
        var redTotal: Double = 0
        var greenTotal: Double = 0
        var blueTotal: Double = 0
        var count: Double = 0

        var y = startY
        while y < endY {
            var x = startX
            while x < endX {
                let index = y * bytesPerRow + x * 4
                blueTotal += Double(buffer[index])
                greenTotal += Double(buffer[index + 1])
                redTotal += Double(buffer[index + 2])
                count += 1
                x += step
            }
            y += step
        }

        guard count > 0 else { return nil }

        return PulseFrameMetrics(
            red: redTotal / count,
            green: greenTotal / count,
            blue: blueTotal / count
        )
    }

}
