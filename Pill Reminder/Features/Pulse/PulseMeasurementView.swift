import AVFoundation
import SwiftUI
import UIKit
import Combine

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

struct PulseReaderView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @StateObject private var reader = PulseCameraPulseReader()
    @State private var previousIdleTimerSetting: Bool?
    @State private var needsCameraStart = true
    let onCompleted: (PulseMeasurementEntry) -> Void

    var body: some View {
        PulseReaderContent(
            snapshot: PulseReaderSnapshot(
                phase: reader.phase,
                progress: reader.progress,
                estimatedBPM: reader.estimatedBPM,
                title: reader.title,
                message: reader.message
            ),
            previewSession: reader.session,
            previewReady: reader.previewReady,
            flashReady: reader.flashReady,
            lensContact: reader.lensContact,
            rearLensCount: reader.rearLensCount,
            lenses: reader.lenses,
            selectedLensID: reader.selectedLensID,
            onSelectLens: { reader.start(lensID: $0) },
            onBack: {
                reader.stop()
                setScreenAwake(false)
                dismiss()
            },
            onAction: {
                if reader.phase == .permissionDenied,
                   let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                } else {
                    reader.start()
                }
            }
        )
        .onDisappear {
            reader.stop()
            setScreenAwake(false)
            needsCameraStart = true
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .background {
                needsCameraStart = reader.phase.isCapturing || reader.phase == .idle
                reader.stop()
            } else if phase == .active {
                let permissionGranted = reader.phase == .permissionDenied && AVCaptureDevice.authorizationStatus(for: .video) == .authorized
                if needsCameraStart || permissionGranted {
                    needsCameraStart = false
                    reader.start()
                }
            }
        }
        .onChange(of: scenePhase == .active && reader.phase.isCapturing, initial: true) { _, keepAwake in
            setScreenAwake(keepAwake)
        }
        .onChange(of: reader.completedBPM) { _, bpm in
            guard let bpm else { return }
            onCompleted(PulseMeasurementEntry(bpm: bpm))
        }
    }

    private func setScreenAwake(_ keepAwake: Bool) {
        if keepAwake {
            guard previousIdleTimerSetting == nil else { return }
            previousIdleTimerSetting = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        } else if let previousIdleTimerSetting {
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerSetting
            self.previousIdleTimerSetting = nil
        }
    }
}

private struct PulseReaderSnapshot {
    let phase: PulseReaderPhase
    let progress: Double
    let estimatedBPM: Int?
    let title: String
    let message: String

    var actionTitle: String {
        switch phase {
        case .permissionDenied: "Open Settings"
        case .completed: "Measure Again"
        default: "Try Again"
        }
    }
}

private struct PulseReaderContent: View {
    let snapshot: PulseReaderSnapshot
    let previewSession: AVCaptureSession
    let previewReady: Bool
    let flashReady: Bool
    let lensContact: PulseLensContact
    let rearLensCount: Int
    let lenses: [PulseCameraChoice]
    let selectedLensID: String?
    let onSelectLens: (String) -> Void
    let onBack: () -> Void
    let onAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color(hex: "6A7282"))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.7), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to History")
                Spacer()
                if lenses.count > 1, snapshot.phase.isCapturing || snapshot.phase == .failed {
                    Menu {
                        ForEach(lenses) { lens in
                            Button {
                                if lens.id != selectedLensID { onSelectLens(lens.id) }
                            } label: {
                                if lens.id == selectedLensID {
                                    Label(lens.name, systemImage: "checkmark")
                                } else {
                                    Text(lens.name)
                                }
                            }
                        }
                    } label: {
                        Label("Switch lens", systemImage: "camera.rotate")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityHint("Starts a new measurement with the selected rear camera")
                }
            }
            .padding(.horizontal, 19)
            .padding(.top, 10)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 22) {
                        if snapshot.phase.isCapturing || snapshot.phase == .idle {
                            let showsGuide = snapshot.phase == .idle || snapshot.phase == .preparing
                            ZStack {
                                cameraGuide
                                    .opacity(showsGuide ? 1 : 0)
                                    .accessibilityHidden(!showsGuide)
                                    .allowsHitTesting(showsGuide)
                                if !showsGuide { measurement }
                            }
                        } else {
                            result
                        }
                    }
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(Color(hex: "F2F2F2").ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if !snapshot.phase.isCapturing, snapshot.phase != .idle {
                footerActions
            }
        }
    }

    private var cameraGuide: some View {
        VStack(spacing: 16) {
            heading("Cover the rear camera")
            Text(rearLensCount > 1
                ? "Cover the selected lens with your index finger. When the preview turns red, keep your finger on that lens."
                : "Lightly cover the rear camera with the pad of your index finger until the preview turns red.")
                .font(.body)
                .foregroundStyle(Color(hex: "6A7282"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Label(lenses.first { $0.id == selectedLensID }?.name ?? "Rear camera", systemImage: "camera")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "222222"))

                ZStack {
                    Color(hex: "222222")
                    PulseCameraPreview(session: previewSession)
                        .opacity(previewReady ? 1 : 0)
                    if !previewReady {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .frame(width: 144, height: 144)
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(.white.opacity(0.65), lineWidth: 3) }
                .accessibilityHidden(true)

                Text(placementStatus)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(lensContact == .tooDark ? Color(hex: "A2560A") : Color(hex: "6A7282"))
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))

            Label(lensContact == .tooDark
                ? "Ease the pressure and slide your fingertip toward the flash until the preview brightens."
                : "Rest the pad of the same finger across the selected lens and the flash. Press lightly.",
                systemImage: "hand.point.up.left")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "454B56"))
                .fixedSize(horizontal: false, vertical: true)
            Text("The measurement starts as soon as we detect your finger.")
                .font(.footnote)
                .foregroundStyle(Color(hex: "6A7282"))
                .multilineTextAlignment(.center)
        }
    }

    private var placementStatus: String {
        guard previewReady else { return "Opening camera…" }
        guard flashReady else { return "Turning on the flash…" }
        switch lensContact {
        case .searching: return "Waiting for fingertip"
        case .tooDark: return "The camera needs more light"
        case .covered: return "Keep the lens covered"
        }
    }

    private var measurement: some View {
        VStack(spacing: 18) {
            PulseReaderHeart(isMeasuring: snapshot.phase == .measuring)
            heading(snapshot.title)
            Text(snapshot.message)
                .font(.body)
                .foregroundStyle(Color(hex: "6A7282"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if snapshot.phase == .measuring {
                Label("Finger detected", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(hex: "15803D"))
            }

            HeartbeatProgressView(progress: snapshot.progress)
                .accessibilityLabel("Measurement progress")
                .accessibilityValue(snapshot.progress.formatted(.percent.precision(.fractionLength(0))))
                .padding(.top, 16)

            if let bpm = snapshot.estimatedBPM {
                Text("~\(bpm) BPM")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color(hex: "FF002B"))
            }
        }
    }

    private var result: some View {
        VStack(spacing: 16) {
            if snapshot.phase == .completed {
                PulseReaderHeart(isMeasuring: false)
            } else {
                Image("app_ic_alert")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .accessibilityHidden(true)
            }

            heading(snapshot.title)
            if snapshot.phase == .completed, let bpm = snapshot.estimatedBPM {
                let category = PulseMeasurementCategory(bpm: bpm)
                Text(category.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(category.color.opacity(0.82), in: Capsule())
            }

            Text(snapshot.message)
                .font(.body)
                .foregroundStyle(Color(hex: "454B56"))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if snapshot.phase == .completed {
                HeartbeatProgressView(progress: 1)
                    .accessibilityHidden(true)
                Text("This estimate is for informational purposes only and is not intended for medical use or diagnosis.")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "6A7282"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(Color(hex: "222222"))
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }

    private var footerActions: some View {
        VStack(spacing: 10) {
            Button(action: onAction) {
                Text(snapshot.actionTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        LinearGradient(colors: [Color(hex: "FF2450"), Color(hex: "FF002B")],
                                       startPoint: .top, endPoint: .bottom),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            if snapshot.phase != .permissionDenied {
                Button("Back to History", action: onBack)
                    .font(.headline)
                    .foregroundStyle(Color(hex: "FF002B"))
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}

private struct PulseReaderHeart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isMeasuring: Bool

    var body: some View {
        Group {
            if isMeasuring && !reduceMotion {
                heart.keyframeAnimator(initialValue: 1.0, repeating: true) { content, scale in
                    content.scaleEffect(CGFloat(scale))
                } keyframes: { _ in
                    CubicKeyframe(1.08, duration: 0.14)
                    CubicKeyframe(1.00, duration: 0.18)
                    CubicKeyframe(1.04, duration: 0.12)
                    CubicKeyframe(1.00, duration: 0.18)
                    LinearKeyframe(1.00, duration: 0.28)
                }
            } else {
                heart
            }
        }
        .accessibilityHidden(true)
    }

    private var heart: some View {
        Image("app_ic_pulse")
            .resizable()
            .scaledToFit()
            .frame(width: 124, height: 124)
    }
}

private struct PulseCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if view.previewLayer.session !== session {
            view.previewLayer.session = session
        }
        if let connection = view.previewLayer.connection,
           connection.videoRotationAngle != 90,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }

    static func dismantleUIView(_ view: PreviewView, coordinator: ()) {
        view.previewLayer.session = nil
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

private struct HeartbeatProgressView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: clampedProgress)
        }
        .frame(height: 42)
    }

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
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
    case adjusting
    case completed
    case failed
    case permissionDenied

    var isCapturing: Bool {
        self == .preparing || self == .measuring || self == .adjusting
    }
}

nonisolated struct PulseCameraChoice: Identifiable, Sendable {
    static let preferenceKey = "pulse.defaultRearCameraID"
    let id: String
    let name: String

    init(_ device: AVCaptureDevice) {
        id = device.uniqueID
        switch device.deviceType {
        case .builtInUltraWideCamera: name = "Ultra Wide · 0.5×"
        case .builtInTelephotoCamera: name = "Telephoto"
        default: name = "Main camera · 1×"
        }
    }
}

nonisolated struct PulseCameraInventory {
    let rearCount: Int
    private let devices: [AVCaptureDevice]

    init() {
        let rear = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video, position: .back
        ).devices
        rearCount = rear.count
        devices = rear.filter { $0.hasTorch && $0.isTorchModeSupported(.on) }
    }

    var choices: [PulseCameraChoice] { devices.map(PulseCameraChoice.init) }

    func device(preferredID: String?) -> AVCaptureDevice? {
        devices.first { $0.uniqueID == preferredID }
            ?? devices.first { $0.deviceType == .builtInWideAngleCamera }
            ?? devices.first
    }
}

nonisolated private struct PulseFrameMetrics {
    let red: Double
    let green: Double
    let blue: Double
    let regionalRed: SIMD4<Double>
    let nativeLuma: Double?

    let lensContact: PulseLensContact
    let maintainsCoverage: Bool

}

nonisolated final class PulseCameraPulseReader: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    @MainActor @Published private(set) var phase: PulseReaderPhase = .idle
    @MainActor @Published private(set) var progress: Double = 0
    @MainActor @Published private(set) var estimatedBPM: Int?
    @MainActor @Published private(set) var previewReady = false
    @MainActor @Published private(set) var flashReady = false
    @MainActor @Published private(set) var lensContact: PulseLensContact = .searching
    @MainActor @Published private(set) var rearLensCount = 0
    @MainActor @Published private(set) var lenses: [PulseCameraChoice] = []
    @MainActor @Published private(set) var selectedLensID: String?
    @MainActor @Published private(set) var completedBPM: Int?
    @MainActor @Published private(set) var title = ""
    @MainActor @Published private(set) var message = ""

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "pulse.camera.session")
    private let analysisQueue = DispatchQueue(label: "pulse.signal.analysis", qos: .userInitiated)
    private let stabilizationDuration: TimeInterval = 1.5
    private let maxMeasurementDuration: TimeInterval = 32
    private var videoDevice: AVCaptureDevice?
    private var samples: [PulseOpticalSample] = []
    private var measurementStartedAt: TimeInterval?
    private var evidence = PulseMeasurementEvidence()
    private var contactGate = PulseContactGate()
    private var analysisPending = false
    private var hasFingerContact = false
    private var lastFrameUsable = false
    private var lastUsableFrameAt: TimeInterval?
    private var torchGate = PulseTorchGate()
    private var torchReady = false
    private var detectedContact = false
    private var lastLensContact: PulseLensContact = .searching
    private var lastEstimateRecordedAt: TimeInterval = 0
    private var lastUIUpdateAt: TimeInterval = 0
    private var lastFrameTime: TimeInterval?
    private var captureSettingsSettled = false
    private var exposureBias: Float?
    private var lockedAt: TimeInterval?
    private var lastAnalysisAt: TimeInterval = 0
    private var shouldCapture = false
    private var sessionRequestGeneration: UInt64 = 0
    private var activeCaptureID: UUID?
    @MainActor private var permissionTask: Task<Void, Never>?
    @MainActor private var requestGeneration: UInt64 = 0
    private var isRunning = false

    @MainActor
    func start(lensID: String? = nil) {
        let requestedLensID = lensID ?? selectedLensID ?? UserDefaults.standard.string(forKey: PulseCameraChoice.preferenceKey)
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
            self.configureAndStart(generation: generation, lensID: requestedLensID)
        }
    }

    @MainActor
    func stop() {
        requestGeneration &+= 1
        permissionTask?.cancel()
        permissionTask = nil
        sessionQueue.async { self.stopCapture() }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        guard isRunning, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let metrics = Self.averageMetrics(from: pixelBuffer) else { return }

        let now = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        guard now.isFinite else { return }
        if let lastFrameTime {
            guard now > lastFrameTime else { return }
            if now - lastFrameTime > PulseSignalAnalyzer.maximumSampleGap {
                resetMeasurementBuffer()
            }
        }
        lastFrameTime = now

        guard torchReady else { return }
        guard torchEmitsLight else {
            torchGate = PulseTorchGate()
            setTorchReadiness(false)
            return
        }

        let contact = metrics.lensContact
        lastLensContact = contact
        if !hasFingerContact {
            guard contactGate.confirm(contact, at: now) else {
                publishPlacement(contact)
                return
            }
            if !detectedContact, let captureID = activeCaptureID {
                detectedContact = true
                sessionQueue.asyncAfter(deadline: .now() + maxMeasurementDuration) { [weak self] in
                    guard let self, self.activeCaptureID == captureID else { return }
                    self.finishCaptureTimeout(generation: self.sessionRequestGeneration)
                }
            }
            hasFingerContact = true
            lastUsableFrameAt = now
        }

        lastFrameUsable = metrics.maintainsCoverage
        guard lastFrameUsable else {
            if let lastUsableFrameAt, now - lastUsableFrameAt <= PulseSignalAnalyzer.maximumSampleGap { return }
            hasFingerContact = false
            resetMeasurementBuffer()
            publishPlacement(contact)
            return
        }

        if let start = measurementStartedAt, let previous = samples.last,
           now - (start + previous.time) > PulseSignalAnalyzer.maximumSampleGap {
            resetMeasurementBuffer()
        }
        if measurementStartedAt == nil { measurementStartedAt = now }
        guard let start = measurementStartedAt else { return }
        let elapsed = now - start
        if !captureSettingsSettled {
            if exposureBias == nil, elapsed >= 0.35, let videoDevice {
                let bias: Float = metrics.red >= 250 ? -1.25 : (metrics.red < 95 && metrics.green < 18 ? 0.7 : 0)
                configureExposure(on: videoDevice, locked: false, bias: bias)
                exposureBias = bias
            }
            let adjusting = videoDevice.map { $0.isAdjustingExposure || $0.isAdjustingWhiteBalance } ?? false
            guard elapsed >= stabilizationDuration, !adjusting || elapsed >= 3 else {
                lastUsableFrameAt = now
                publishThrottled(at: now, phase: .measuring, progress: 0, estimatedBPM: nil,
                                 title: "Preparing camera", message: "Hold your fingertip lightly over the lens and flash.")
                return
            }
            if let videoDevice { configureExposure(on: videoDevice, locked: true) }
            captureSettingsSettled = true
            lockedAt = now
        }
        if let lockedAt, now - lockedAt < 0.25 { lastUsableFrameAt = now; return }
        let sample = PulseOpticalSample(
            time: elapsed, red: metrics.red, green: metrics.green, blue: metrics.blue,
            regionalRed: metrics.regionalRed, nativeLuma: metrics.nativeLuma
        )
        if let previous = samples.last,
           abs(sample.brightness - previous.brightness) > max(8, previous.brightness * 0.12) {
            lastFrameUsable = false
            if let lastUsableFrameAt, now - lastUsableFrameAt <= PulseSignalAnalyzer.maximumSampleGap { return }
            resetMeasurementBuffer()
            publishThrottled(at: now, phase: .adjusting, progress: 0, estimatedBPM: nil,
                             title: "Hold still", message: "Keep your fingertip in its new position.")
            return
        }
        lastUsableFrameAt = now
        samples.append(sample)

        if elapsed < stabilizationDuration + 5 {
            publishThrottled(
                at: now, phase: .measuring, progress: 0, estimatedBPM: nil,
                title: "Measuring pulse", message: "Keep your fingertip lightly on the lens."
            )
        } else {
            scheduleAnalysis(at: now, startedAt: start, elapsed: elapsed)
        }
    }

    private func scheduleAnalysis(at now: TimeInterval, startedAt start: TimeInterval, elapsed: TimeInterval) {
        guard !analysisPending, now - lastAnalysisAt >= 0.5, let captureID = activeCaptureID else { return }
        lastAnalysisAt = now
        analysisPending = true

        let window = samples.filter { $0.time >= elapsed - PulseSignalAnalyzer.longestAnalysisWindow }
        analysisQueue.async { [weak self] in
            let estimate = PulseSignalAnalyzer.estimateRecentPulse(from: window)
            guard let self else { return }
            self.sessionQueue.async { [weak self] in
                guard let self, self.activeCaptureID == captureID, self.measurementStartedAt == start else { return }
                self.analysisPending = false
                guard self.torchReady, self.torchEmitsLight, self.hasFingerContact, self.lastFrameUsable else { return }
                self.receiveEstimate(estimate, at: now, elapsed: elapsed)
            }
        }
    }

    private func receiveEstimate(_ estimate: PulseEstimate?, at now: TimeInterval, elapsed: TimeInterval) {
        if now - lastEstimateRecordedAt >= 0.9 {
            lastEstimateRecordedAt = now
            if let finalEstimate = evidence.record(estimate) {
                completeMeasurement(with: finalEstimate)
                return
            }
        }

        let weakSignal = elapsed - (samples.first?.time ?? elapsed) >= 12 && estimate == nil && evidence.progress == 0
        publishThrottled(
            at: now,
            phase: .measuring,
            progress: evidence.progress,
            estimatedBPM: estimate?.bpm,
            title: weakSignal ? "Listening for a steady beat" : "Measuring pulse",
            message: weakSignal
                ? "The lens is covered. Rest your hand and keep a light, steady touch."
                : "Keep your fingertip lightly on the lens."
        )
    }

    private func completeMeasurement(with estimate: PulseEstimate) {
        let generation = sessionRequestGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.requestGeneration == generation else { return }
            self.phase = .completed
            self.previewReady = false
            self.progress = 1
            self.estimatedBPM = estimate.bpm
            self.completedBPM = estimate.bpm
            self.title = "\(estimate.bpm) BPM"
            self.message = "Saved to your pulse history."
        }
        stopCapture()
    }

    @MainActor
    private func resetState() {
        phase = .preparing
        progress = 0
        estimatedBPM = nil
        previewReady = false
        flashReady = false
        lensContact = .searching
        completedBPM = nil
        title = ""
        message = ""
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.stopCapture()
            self.lastFrameTime = nil
            self.detectedContact = false
            self.lastLensContact = .searching
            self.lastUIUpdateAt = 0
        }
    }

    private func configureAndStart(generation: UInt64, lensID: String?) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.shouldCapture, self.sessionRequestGeneration == generation, !self.isRunning else { return }

            self.session.beginConfiguration()

            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }

            let inventory = PulseCameraInventory()
            guard let device = inventory.device(preferredID: lensID) else {
                self.session.commitConfiguration()
                self.updatePhase(
                    .failed,
                    title: "Camera Unavailable",
                    message: inventory.rearCount == 0 ? "This device doesn't have a supported rear camera." : "The rear camera needs a flashlight for this measurement.",
                    generation: generation
                )
                return
            }

            let lensChoices = inventory.choices
            let selectedID = device.uniqueID
            let cameraCount = inventory.rearCount
            DispatchQueue.main.async { [weak self] in
                guard let self, self.requestGeneration == generation else { return }
                self.lenses = lensChoices
                self.selectedLensID = selectedID
                self.rearLensCount = cameraCount
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
                let preset: AVCaptureSession.Preset = self.session.canSetSessionPreset(.vga640x480) ? .vga640x480 : .low
                if self.session.canSetSessionPreset(preset) { self.session.sessionPreset = preset }
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
            let fullRangeYUV = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            let pixelFormat = output.availableVideoPixelFormatTypes.contains(fullRangeYUV)
                ? fullRangeYUV : kCVPixelFormatType_32BGRA
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: pixelFormat]
            self.configureExposure(on: device, locked: false)
            self.configureFrameRate(on: device)
            self.session.startRunning()
            self.isRunning = self.session.isRunning
            guard self.isRunning else {
                self.updatePhase(.failed, title: "Camera Unavailable", message: "Unable to start the camera.", generation: generation)
                return
            }
            let captureID = UUID()
            self.activeCaptureID = captureID
            self.monitorTorch(captureID: captureID)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.requestGeneration == generation, self.phase.isCapturing else { return }
                self.previewReady = true
            }
            self.sessionQueue.asyncAfter(deadline: .now() + 45) { [weak self] in
                guard let self, self.activeCaptureID == captureID, !self.detectedContact else { return }
                self.finishCaptureTimeout(generation: generation)
            }
        }
    }

    private func finishCaptureTimeout(generation: UInt64) {
        let title: String
        let message: String
        if self.lastFrameTime == nil {
            title = "No camera image"
            message = "The camera stopped sending frames. Try opening the measurement again."
        } else if self.lastLensContact == .tooDark {
            title = "The lens needs more light"
            message = "Rest the same fingertip lightly across the selected lens and the flash."
        } else if self.hasFingerContact && self.lastFrameUsable {
            title = "No steady pulse detected"
            message = "Ease the pressure and rest the same fingertip across the lit flash and the selected lens, then try again."
        } else if self.detectedContact {
            title = "Finger contact was lost"
            message = "Rest your hand and keep the same lens covered until a result appears."
        } else {
            title = "Finger wasn’t detected"
            message = "Use the preview to find the active lens. Rest the pad of your index finger over it."
        }
        self.updatePhase(.failed, title: title, message: message, generation: generation)
        self.stopCapture()
    }

    private var torchEmitsLight: Bool {
        guard let videoDevice else { return false }
        return videoDevice.torchMode == .on && videoDevice.isTorchActive && videoDevice.torchLevel > 0
    }

    private func monitorTorch(captureID: UUID) {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        guard isRunning, activeCaptureID == captureID, let device = videoDevice else { return }
        let canEnable = device.hasTorch && device.isTorchAvailable && device.isTorchModeSupported(.on)
        let action = torchGate.update(
            isLit: torchEmitsLight, canEnable: canEnable, at: ProcessInfo.processInfo.systemUptime
        )
        setTorchReadiness(action == .ready)

        if action == .unavailable {
            let generation = sessionRequestGeneration
            stopCapture()
            updatePhase(
                .failed, title: "Flash didn’t stay on",
                message: "Pulse measurement needs the rear flash to stay lit. Try again when the flash is available.",
                generation: generation
            )
            return
        }
        if action == .enable { setTorchMode(.on, on: device) }

        sessionQueue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.monitorTorch(captureID: captureID)
        }
    }

    private func setTorchReadiness(_ ready: Bool) {
        guard torchReady != ready else { return }
        torchReady = ready
        if !ready {
            hasFingerContact = false
            lastFrameUsable = false
            resetMeasurementBuffer()
        }

        let generation = sessionRequestGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.requestGeneration == generation, self.phase.isCapturing else { return }
            self.flashReady = ready
            if !ready {
                self.phase = .preparing
                self.lensContact = .searching
                self.progress = 0
                self.estimatedBPM = nil
            }
        }
    }

    private func setTorchMode(_ mode: AVCaptureDevice.TorchMode, on device: AVCaptureDevice) {
        guard device.hasTorch, device.isTorchModeSupported(mode) else { return }
        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }
        guard mode == .off || device.isTorchAvailable else { return }
        if mode == .on, device.torchMode == .on {
            try? device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
        } else {
            device.torchMode = mode
        }
    }

    private func configureFrameRate(on device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }
        guard device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
            $0.minFrameRate <= 30 && $0.maxFrameRate >= 30
        }) else { return }
        let duration = CMTime(value: 1, timescale: 30)
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
    }

    private func configureExposure(on device: AVCaptureDevice, locked: Bool, bias: Float = 0) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }
        if !locked && device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
        }
        let exposure: AVCaptureDevice.ExposureMode = locked ? .locked : .continuousAutoExposure
        let whiteBalance: AVCaptureDevice.WhiteBalanceMode = locked ? .locked : .continuousAutoWhiteBalance
        if device.isExposureModeSupported(exposure) { device.exposureMode = exposure }
        if device.isWhiteBalanceModeSupported(whiteBalance) { device.whiteBalanceMode = whiteBalance }
        let focus: AVCaptureDevice.FocusMode = locked ? .locked : .continuousAutoFocus
        if device.isFocusModeSupported(focus) { device.focusMode = focus }
        if !locked, device.isExposureModeSupported(.continuousAutoExposure) {
            let target = min(device.maxExposureTargetBias, max(device.minExposureTargetBias, bias))
            if abs(target - device.exposureTargetBias) > 0.01 { device.setExposureTargetBias(target) }
        }
    }

    private func resetMeasurementBuffer() {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        measurementStartedAt = nil
        contactGate = PulseContactGate()
        analysisPending = false
        evidence = PulseMeasurementEvidence()
        lastEstimateRecordedAt = 0
        if captureSettingsSettled || exposureBias != nil, let videoDevice { configureExposure(on: videoDevice, locked: false) }
        captureSettingsSettled = false
        exposureBias = nil
        lockedAt = nil
        lastUsableFrameAt = nil
        lastAnalysisAt = 0
        samples.removeAll(keepingCapacity: true)
    }

    private func stopCapture() {
        dispatchPrecondition(condition: .onQueue(sessionQueue))
        activeCaptureID = nil
        shouldCapture = false
        isRunning = false
        hasFingerContact = false
        lastFrameUsable = false
        torchReady = false
        torchGate = PulseTorchGate()
        resetMeasurementBuffer()
        if let videoDevice { setTorchMode(.off, on: videoDevice) }
        if session.isRunning { session.stopRunning() }
        videoDevice = nil
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
            self.previewReady = false
            self.title = title
            self.message = message
        }
    }

    private func publishPlacement(_ contact: PulseLensContact) {
        let generation = sessionRequestGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.requestGeneration == generation else { return }
            if self.phase != .preparing {
                self.phase = .preparing
                self.progress = 0
                self.estimatedBPM = nil
            }
            if self.lensContact != contact { self.lensContact = contact }
            if !self.message.isEmpty { self.message = "" }
        }
    }

    private func publishThrottled(
        at now: TimeInterval,
        phase: PulseReaderPhase,
        progress: Double,
        estimatedBPM: Int?,
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
            self.title = title
            self.message = message
        }
    }

    private static func averageMetrics(from pixelBuffer: CVPixelBuffer) -> PulseFrameMetrics? {
        guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let readsLuma = pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        let primaryBase = readsLuma
            ? CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) : CVPixelBufferGetBaseAddress(pixelBuffer)
        guard let primary = primaryBase?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let primaryStride = readsLuma
            ? CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) : CVPixelBufferGetBytesPerRow(pixelBuffer)
        let chroma = readsLuma
            ? CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)?.assumingMemoryBound(to: UInt8.self) : nil
        guard readsLuma ? chroma != nil : pixelFormat == kCVPixelFormatType_32BGRA else { return nil }
        let chromaStride = readsLuma ? CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1) : 0
        let matrix = CVBufferCopyAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, nil) as? String
        let redLumaWeight: Double
        let blueLumaWeight: Double
        if matrix == (kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String) {
            (redLumaWeight, blueLumaWeight) = (0.2126, 0.0722)
        } else if matrix == (kCVImageBufferYCbCrMatrix_ITU_R_2020 as String) {
            (redLumaWeight, blueLumaWeight) = (0.2627, 0.0593)
        } else {
            (redLumaWeight, blueLumaWeight) = (0.299, 0.114)
        }
        let greenLumaWeight = 1 - redLumaWeight - blueLumaWeight
        let step = max(2, min(width, height) / 120)
        let startX = width / 4
        let endX = width - startX
        let startY = height / 4
        let endY = height - startY
        var redTotal: Double = 0
        var greenTotal: Double = 0
        var blueTotal: Double = 0
        var lumaTotal: Double = 0
        var count: Double = 0
        var fingerColored: Double = 0
        var regionalRed = SIMD4<Double>.zero
        var regionalCount = SIMD4<Double>.zero

        var y = startY
        while y < endY {
            let rowOffset = y < height / 2 ? 0 : 2
            var x = startX
            while x < endX {
                let red: Double
                let green: Double
                let blue: Double
                if let chroma {
                    let luma = Double(primary[y * primaryStride + x])
                    let index = (y / 2) * chromaStride + (x / 2) * 2
                    let blueDifference = 2 * (1 - blueLumaWeight) * (Double(chroma[index]) - 128)
                    let redDifference = 2 * (1 - redLumaWeight) * (Double(chroma[index + 1]) - 128)
                    red = min(255, max(0, luma + redDifference))
                    blue = min(255, max(0, luma + blueDifference))
                    green = min(255, max(0, luma - (redLumaWeight * redDifference + blueLumaWeight * blueDifference) / greenLumaWeight))
                    lumaTotal += luma
                } else {
                    let index = y * primaryStride + x * 4
                    blue = Double(primary[index])
                    green = Double(primary[index + 1])
                    red = Double(primary[index + 2])
                }
                blueTotal += blue
                greenTotal += green
                redTotal += red
                let region = rowOffset + (x < width / 2 ? 0 : 1)
                regionalRed[region] += red
                regionalCount[region] += 1
                if PulseLensContact.isFingerColored(red: red, green: green, blue: blue) { fingerColored += 1 }
                count += 1
                x += step
            }
            y += step
        }

        guard count > 0 else { return nil }

        let red = redTotal / count
        let green = greenTotal / count
        let blue = blueTotal / count
        let coverage = fingerColored / count
        return PulseFrameMetrics(
            red: red, green: green, blue: blue,
            regionalRed: regionalRed / regionalCount.replacing(with: 1, where: regionalCount .== 0),
            nativeLuma: readsLuma ? lumaTotal / count : nil,
            lensContact: .classify(red: red, green: green, blue: blue, fingerColoredFraction: coverage),
            maintainsCoverage: PulseLensContact.maintainsCoverage(red: red, fingerColoredFraction: coverage)
        )
    }

}
