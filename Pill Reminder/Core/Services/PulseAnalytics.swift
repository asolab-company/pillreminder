import Adapty
import AdaptyLogger
import AmplitudeSwift
import Foundation
import StoreKit

@MainActor
final class PulseAnalytics {
    static let shared = PulseAnalytics()

    private let amplitude = Amplitude(configuration: Configuration(
        apiKey: "b3201c21fabb6a33b4b9b8ef0ec8d4ee",
        logLevel: .off,
        trackingOptions: TrackingOptions().disableTrackIDFV().disableTrackIpAddress(),
        autocapture: [.sessions, .appLifecycles],
        enableAutoCaptureRemoteConfig: false,
        enableDiagnostics: false
    ))

    private var isActive = false
    private var activation: Task<Bool, Never>?

    private init() {}

    @discardableResult
    func activate() async -> Bool {
        if isActive { return true }
        if let activation { return await activation.value }
        let task = Task { () -> Bool in
            do {
                let configuration = AdaptyConfiguration.builder(withAPIKey: "public_live_6STjrrBY.oVyEJA7PdpqVLMydht2f")
                    .with(logLevel: .error)
                    .with(observerMode: true)
                    .with(idfaCollectionDisabled: true)
                    .with(ipAddressCollectionDisabled: true)
                    .build()
                try await Adapty.activate(with: configuration)
                if let id = amplitude.getDeviceId() {
                    Task { try? await Adapty.setIntegrationIdentifier(.amplitudeDeviceId(id)) }
                }
                return true
            } catch {
                return false
            }
        }
        activation = task
        isActive = await task.value
        activation = nil
        return isActive
    }

    func track(_ event: String, productID: String? = nil) {
        amplitude.track(eventType: event, eventProperties: productID.map { ["product_id": $0] })
    }

    func report(_ result: VerificationResult<StoreKit.Transaction>) async -> Bool {
        guard case .verified(let transaction) = result else { return false }
        if transaction.environment == .xcode { return true }
        guard await activate() else { return false }
        do {
            try await Adapty.reportTransaction(result)
            return true
        } catch {
            return false
        }
    }
}
