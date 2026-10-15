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
    @Published var latestErrorMessage: String?

    private var didLoadProducts = false
    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = observeTransactionUpdates()
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func loadProductsIfNeeded() async {
        guard !didLoadProducts, !isLoadingProducts else { return }
        await loadProducts()
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: AppConstants.Store.productIDs)
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            didLoadProducts = true
        } catch {
            latestErrorMessage = "Failed to load products. Please try again."
        }
    }

    func priceText(for productID: String, periodSuffix: String) -> String {
        guard let product = productsByID[productID] else {
            return "..."
        }

        return "\(product.displayPrice) / \(periodSuffix)"
    }

    func purchase(productID: String) async -> Bool {
        latestErrorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            if productsByID[productID] == nil {
                await loadProducts()
            }

            guard let product = productsByID[productID] else {
                latestErrorMessage = "This product is unavailable right now."
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
