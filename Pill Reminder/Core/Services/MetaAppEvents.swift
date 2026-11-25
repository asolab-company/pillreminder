import AppTrackingTransparency
import FBSDKCoreKit
import StoreKit
import UIKit

@MainActor
final class MetaAppEvents {
    static let shared = MetaAppEvents()

    private let attribution = TrialAttribution()
    private let hasCredentials: Bool
    private var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    private var isInitialized = false
    private var authorizationTask: Task<Void, Never>?

    private init() {
        let info = Bundle.main.infoDictionary
        let id = (info?["FacebookAppID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let token = (info?["FacebookClientToken"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        hasCredentials = !id.isEmpty && id.allSatisfy { $0.isASCII && $0.isNumber }
            && !token.isEmpty && !token.contains("$(")
    }

    func configure(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        self.launchOptions = launchOptions
        initializeIfAuthorized()
    }

    func didBecomeActive() {
        guard hasCredentials, UIApplication.shared.applicationState == .active else { return }
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized:
            initializeIfAuthorized()
        case .notDetermined:
            guard authorizationTask == nil else { return }
            authorizationTask = Task {
                defer { authorizationTask = nil }
                try? await Task.sleep(for: .milliseconds(500))
                guard UIApplication.shared.applicationState == .active else { return }
                if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                    _ = await ATTrackingManager.requestTrackingAuthorization()
                }
                applyAuthorization()
            }
        case .denied, .restricted:
            applyAuthorization()
        @unknown default:
            applyAuthorization()
        }
    }

    func openWebEntry(_ url: URL) -> Bool {
        guard TrialAttribution.isWebEntry(url, scheme: Bundle.main.bundleIdentifier) else { return false }
        let status = ATTrackingManager.trackingAuthorizationStatus
        if hasCredentials, status == .authorized || status == .notDetermined { attribution.enteredFromWeb() }
        return true
    }

    func beginPurchase(_ productID: String) -> UUID? {
        guard isAuthorized else { return nil }
        return attribution.begin(productID: productID)
    }

    func cancel(_ attempt: UUID?) { attribution.cancel(attempt) }

    func process(_ transaction: StoreKit.Transaction, attempt: UUID? = nil) {
        guard isAuthorized else { return }
        guard AppConstants.Store.productIDs.contains(transaction.productID),
              transaction.productType == .autoRenewable, transaction.reason == .purchase,
              transaction.ownershipType == .purchased, transaction.revocationDate == nil, !transaction.isUpgraded else { return }
        let isTrial = transaction.offer?.paymentMode == .freeTrial && transaction.environment != .xcode
        guard let source = attribution.consume(id: transaction.id, productID: transaction.productID,
                                               purchasedAt: transaction.purchaseDate, isTrial: isTrial, attemptID: attempt) else { return }
        initializeIfAuthorized()
        AppEvents.shared.logEvent(.startTrial, parameters: [AppEvents.ParameterName(rawValue: "trial_source"): source.rawValue])
    }

    private var isAuthorized: Bool {
        hasCredentials && ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    private func initializeIfAuthorized() {
        guard isAuthorized else { return }
        if !isInitialized {
            ApplicationDelegate.shared.application(UIApplication.shared, didFinishLaunchingWithOptions: launchOptions)
            isInitialized = true
            launchOptions = nil
        }
        Settings.shared.isAdvertiserIDCollectionEnabled = true
    }

    private func applyAuthorization() {
        if isAuthorized {
            initializeIfAuthorized()
        } else if ATTrackingManager.trackingAuthorizationStatus != .notDetermined {
            if isInitialized { Settings.shared.isAdvertiserIDCollectionEnabled = false }
            attribution.clearPending()
        }
    }
}
