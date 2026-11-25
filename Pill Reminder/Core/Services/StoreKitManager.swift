import Foundation
import Combine
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    @Published private(set) var productsByID: [String: Product] = [:]
    @Published private(set) var hasActiveSubscription = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var productLoadErrorMessage: String?
    @Published var latestErrorMessage: String?

    private var didLoadProducts = false
    private var entitlementRefresh = 0
    private var reportingTransactions: Set<UInt64> = []
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
            didLoadProducts = !products.isEmpty

            if products.isEmpty {
                productLoadErrorMessage = "Subscriptions are unavailable right now. Please try again."
            }
        } catch is CancellationError {
            return
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

    func purchase(productID: String) async -> Bool {
        guard !isPurchasing, !isRestoring else { return false }
        latestErrorMessage = nil
        guard !isLoadingProducts else {
            latestErrorMessage = "Subscription options are still loading. Please try again."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        var attempt: UUID?

        do {
            if productsByID[productID] == nil {
                await loadProducts()
            }

            guard let product = productsByID[productID] else {
                latestErrorMessage = productLoadErrorMessage ?? "This product is unavailable right now."
                return false
            }

            PulseAnalytics.shared.track("purchase_started", productID: productID)
            attempt = MetaAppEvents.shared.beginPurchase(productID)
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    MetaAppEvents.shared.cancel(attempt)
                    latestErrorMessage = "Purchase verification failed."
                    return false
                }

                MetaAppEvents.shared.process(transaction, attempt: attempt)
                await refreshEntitlementStatus()
                Task { await reportAndFinish(verification) }
                PulseAnalytics.shared.track("purchase_verified", productID: productID)
                return hasActiveSubscription

            case .pending:
                PulseAnalytics.shared.track("purchase_pending", productID: productID)
                latestErrorMessage = "Purchase is pending approval."
                return false

            case .userCancelled:
                MetaAppEvents.shared.cancel(attempt)
                PulseAnalytics.shared.track("purchase_cancelled", productID: productID)
                return false

            @unknown default:
                MetaAppEvents.shared.cancel(attempt)
                latestErrorMessage = "Unknown purchase state."
                return false
            }
        } catch {
            MetaAppEvents.shared.cancel(attempt)
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
            } else {
                PulseAnalytics.shared.track("purchases_restored")
                Task {
                    for await result in Transaction.currentEntitlements {
                        if case .verified(let transaction) = result, AppConstants.Store.productIDs.contains(transaction.productID) {
                            await reportAndFinish(result)
                        }
                    }
                }
            }

            return hasActiveSubscription
        } catch {
            latestErrorMessage = "Restore failed. Please try again."
            return false
        }
    }

    func refreshEntitlementStatus() async {
        entitlementRefresh += 1
        let refresh = entitlementRefresh
        var activeTransaction: Transaction?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard AppConstants.Store.productIDs.contains(transaction.productID) else { continue }
            guard transaction.productType == .autoRenewable, !transaction.isUpgraded, transaction.revocationDate == nil else { continue }

            activeTransaction = transaction
            break
        }

        guard refresh == entitlementRefresh else { return }
        hasActiveSubscription = activeTransaction != nil
    }

    func retryUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result { MetaAppEvents.shared.process(transaction) }
            await reportAndFinish(result)
        }
    }

    private func reportAndFinish(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result, AppConstants.Store.productIDs.contains(transaction.productID),
              reportingTransactions.insert(transaction.id).inserted else { return }
        defer { reportingTransactions.remove(transaction.id) }
        if await PulseAnalytics.shared.report(result) { await transaction.finish() }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result, AppConstants.Store.productIDs.contains(transaction.productID) else { continue }
                MetaAppEvents.shared.process(transaction)
                await self?.refreshEntitlementStatus()
                Task { [weak self] in await self?.reportAndFinish(result) }
            }
        }
    }
}
