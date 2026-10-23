import Foundation
import Combine
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    private static let legacyPremiumFlagKey = "pill_reminder_web_premium_unlocked"

    @Published private(set) var productsByID: [String: Product] = [:]
    @Published private(set) var hasActiveSubscription = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var productLoadErrorMessage: String?
    @Published var latestErrorMessage: String?

    private var didLoadProducts = false
    private var transactionUpdatesTask: Task<Void, Never>?
    private let productLoadTimeout: Duration
    private var productRequestID: UUID?
    private var productRequestContinuation: CheckedContinuation<[Product], Error>?
    private var productRequestTask: Task<Void, Never>?
    private var productTimeoutTask: Task<Void, Never>?

    init(productLoadTimeout: Duration = .seconds(15)) {
        self.productLoadTimeout = productLoadTimeout
        transactionUpdatesTask = observeTransactionUpdates()
    }

    deinit {
        transactionUpdatesTask?.cancel()
        productRequestTask?.cancel()
        productTimeoutTask?.cancel()
        productRequestContinuation?.resume(throwing: CancellationError())
    }

    func loadProductsIfNeeded() async {
        guard !didLoadProducts, !isLoadingProducts else { return }
        await loadProducts()
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        didLoadProducts = false
        productLoadErrorMessage = nil
        defer { isLoadingProducts = false }

        do {
            let products = try await requestProductsWithTimeout()
            try Task.checkCancellation()
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            let missingIDs = Set(AppConstants.Store.productIDs).subtracting(productsByID.keys)
            didLoadProducts = missingIDs.isEmpty

            if !missingIDs.isEmpty {
                productLoadErrorMessage = products.isEmpty
                    ? "Subscriptions are unavailable right now. Please try again."
                    : "Some plans are unavailable. Choose an available plan or try again."
            }
        } catch is CancellationError {

        } catch ProductLoadError.timedOut {
            productLoadErrorMessage = "Loading subscriptions took too long. Check your connection and try again."
        } catch {
            productLoadErrorMessage = "Could not load subscriptions. Check your connection and try again."
        }
    }

    private func requestProductsWithTimeout() async throws -> [Product] {
        let requestID = UUID()
        let timeout = productLoadTimeout

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                productRequestID = requestID
                productRequestContinuation = continuation

                productRequestTask = Task { [weak self] in
                    do {
                        let products = try await Product.products(for: AppConstants.Store.productIDs)
                        self?.completeProductRequest(.success(products), requestID: requestID)
                    } catch {
                        self?.completeProductRequest(.failure(error), requestID: requestID)
                    }
                }

                productTimeoutTask = Task { [weak self] in
                    do {
                        try await Task.sleep(for: timeout)
                    } catch {
                        return
                    }
                    self?.completeProductRequest(.failure(ProductLoadError.timedOut), requestID: requestID)
                }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                self?.completeProductRequest(.failure(CancellationError()), requestID: requestID)
            }
        }
    }

    private func completeProductRequest(_ result: Result<[Product], Error>, requestID: UUID) {

        guard productRequestID == requestID else { return }
        let continuation = productRequestContinuation
        productRequestID = nil
        productRequestContinuation = nil
        productRequestTask?.cancel()
        productTimeoutTask?.cancel()
        productRequestTask = nil
        productTimeoutTask = nil
        continuation?.resume(with: result)
    }

    private enum ProductLoadError: Error {
        case timedOut
    }

    func priceText(for productID: String, periodSuffix: String) -> String {
        guard let product = productsByID[productID] else {
            return isLoadingProducts ? "Loading…" : "Unavailable"
        }

        return "\(product.displayPrice) / \(periodSuffix)"
    }

    func purchase(productID: String) async -> Bool {
        guard !isPurchasing, !isRestoring else { return false }
        latestErrorMessage = nil
        guard !isLoadingProducts else {
            latestErrorMessage = "Subscription options are still loading. Please try again."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            if productsByID[productID] == nil {
                await loadProducts()
            }

            guard let product = productsByID[productID] else {
                latestErrorMessage = productLoadErrorMessage ?? "This product is unavailable right now."
                return false
            }

            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    latestErrorMessage = "Purchase verification failed."
                    return false
                }

                await transaction.finish()
                await refreshEntitlementStatus()
                AppsFlyerService.shared.trackSubscription(productID: productID)
                return hasActiveSubscription

            case .pending:
                latestErrorMessage = "Purchase is pending approval."
                return false

            case .userCancelled:
                return false

            @unknown default:
                latestErrorMessage = "Unknown purchase state."
                return false
            }
        } catch {
            latestErrorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    func restorePurchases() async -> Bool {
        guard !isPurchasing, !isRestoring else { return false }
        latestErrorMessage = nil
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlementStatus()

            if !hasActiveSubscription {
                latestErrorMessage = "No active purchases were found."
            }

            return hasActiveSubscription
        } catch {
            latestErrorMessage = "Restore failed. Please try again."
            return false
        }
    }

    func refreshEntitlementStatus() async {
        var isUnlocked = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard AppConstants.Store.productIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }

            isUnlocked = true
            break
        }

        hasActiveSubscription = isUnlocked || hasLegacyPremiumAccess()
    }

    private func hasLegacyPremiumAccess() -> Bool {
        UserDefaults.standard.bool(forKey: Self.legacyPremiumFlagKey)
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlementStatus()
            }
        }
    }
}
