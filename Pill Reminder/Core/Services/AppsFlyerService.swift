import AppTrackingTransparency
import Foundation
import UIKit
import AppsFlyerLib

enum AppsFlyerConfig {
    static let devKey = "cSRFayvDVGvzuDdmHNu9BZ"
    static let appID = AppConstants.Links.appStoreAppID
}

@MainActor
final class AppsFlyerService {
    static let shared = AppsFlyerService()

    private var isConfigured = false
    private var sessionGate = AttributionSessionGate()
    private var isATTRequestInFlight = false
    private var attRequestTask: Task<Void, Never>?

    private init() {}

    func configure(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        guard !isConfigured else { return }
        isConfigured = true

        let sdk = AppsFlyerLib.shared()
        sdk.initialize(devKey: AppsFlyerConfig.devKey, appId: AppsFlyerConfig.appID)
        sdk.isDebug = false
        sdk.handleLaunchOptions(launchOptions)
        sdk.registerSessionReadyListener { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.sessionGate.markReady()
                self.startRespectingTrackingAuthorization()
            }
        }
    }

    func startRespectingTrackingAuthorization() {
        guard UIApplication.shared.applicationState == .active else { return }

        switch ATTrackingManager.trackingAuthorizationStatus {
        case .notDetermined:
            scheduleTrackingAuthorizationRequest()
        case .authorized, .denied, .restricted:
            startSessionIfReady()
        @unknown default:
            break
        }
    }

    func sceneDidEnterBackground() {
        sessionGate.enterBackground()
    }

    func handleOpen(url: URL) {
        AppsFlyerLib.shared().handleOpen(url, options: nil)
    }

    func continueUserActivity(_ userActivity: NSUserActivity) {
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
    }

    func trackSubscription(productID: String) {
        AppsFlyerLib.shared().logEvent("af_app_subscription", withValues: [
            "product_id": productID,
            "event_source": "sugarpink_ios_app",
            "event_context": "subscription_purchase_success",
        ])
    }

    private func scheduleTrackingAuthorizationRequest() {
        guard attRequestTask == nil, !isATTRequestInFlight else { return }
        attRequestTask = Task { [weak self] in
            defer { self?.attRequestTask = nil }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self,
                  UIApplication.shared.applicationState == .active else { return }
            guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
                self.startSessionIfReady()
                return
            }

            self.isATTRequestInFlight = true
            _ = await ATTrackingManager.requestTrackingAuthorization()
            self.isATTRequestInFlight = false
            self.startSessionIfReady()
        }
    }

    private func startSessionIfReady() {
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard sessionGate.takeReadySession(
            trackingStatus: status,
            isActive: UIApplication.shared.applicationState == .active
        ) else { return }
        AppsFlyerLib.shared().start()
    }
}

nonisolated struct AttributionSessionGate {
    private var isReady = false
    private var hasStartedForegroundSession = false

    mutating func markReady() {
        guard !hasStartedForegroundSession else { return }
        isReady = true
    }

    mutating func enterBackground() {
        isReady = false
        hasStartedForegroundSession = false
    }

    mutating func takeReadySession(
        trackingStatus: ATTrackingManager.AuthorizationStatus,
        isActive: Bool
    ) -> Bool {
        guard isReady, isActive else { return false }
        switch trackingStatus {
        case .authorized, .denied, .restricted:
            isReady = false
            hasStartedForegroundSession = true
            return true
        case .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
}
