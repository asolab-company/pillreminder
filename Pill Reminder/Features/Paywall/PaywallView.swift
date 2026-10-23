import SwiftUI

struct PaywallView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @AppStorage("hasUnlockedPro") private var hasUnlockedPro = false

    @State private var selectedPlan: SubscriptionPlan = .yearly
    @State private var isStoreAlertPresented = false
    @State private var storeAlertMessage = ""

    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let longestSide = max(proxy.size.width, proxy.size.height)
            let isSEDevice = longestSide <= 667
            let titleSize: CGFloat = isSEDevice ? 30 : 36
            let subtitleSize: CGFloat = isSEDevice ? 14 : 15

            VStack(spacing: 0) {
                PaywallHeroView()
                    .frame(width: proxy.size.width)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(y: -topInset)
                    .padding(.bottom, -topInset)

                VStack(spacing: 0) {
                    Text("Stay Consistent.")
                        .font(.system(size: titleSize, weight: .heavy))
                        .foregroundStyle(Color(hex: "FF0A3D"))
                        .padding(.top, isSEDevice ? 8 : 14)

                    Text("Stay Healthy.")
                        .font(.system(size: titleSize, weight: .heavy))
                        .foregroundStyle(Color(hex: "687286"))

                    Text("Unlock full medication tracking, smart reminders,\nand a complete history of your doses.")
                        .font(.system(size: subtitleSize, weight: .regular))
                        .foregroundStyle(Color(hex: "3B4353"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)

                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(2)
                        .padding(.top, 12)
                        .padding(.horizontal, 26)

                    VStack(spacing: 10) {
                        ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                            Button {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    selectedPlan = plan
                                }
                            } label: {
                                PaywallPlanCard(
                                    plan: plan,
                                    subtitle: storeKitManager.priceText(
                                        for: plan.productID,
                                        periodSuffix: plan.periodSuffix
                                    ),
                                    isSelected: selectedPlan == plan
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isStoreBusy || storeKitManager.productsByID[plan.productID] == nil)
                            .accessibilityValue(selectedPlan == plan ? "Selected" : "")
                            .accessibilityIdentifier("paywall.plan.\(plan.productID)")
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)

                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Cancel Anytime")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(Color(hex: "FF0A3D"))
                    .padding(.top, 12)

                    purchaseButton
                        .padding(.horizontal, 26)
                        .padding(.top, 14)

                    productLoadingError

                    HStack(spacing: 28) {
                        Button("Privacy Policy") {
                            openURL(AppConstants.Links.privacyPolicy)
                        }
                        .buttonStyle(.plain)
                        Button("Skip", action: onSkip)
                            .buttonStyle(.plain)
                        Button("Restore") {
                            Task {
                                let success = await storeKitManager.restorePurchases()
                                if success {
                                    hasUnlockedPro = true
                                    onContinue()
                                } else if let message = storeKitManager.latestErrorMessage {
                                    storeAlertMessage = message
                                    isStoreAlertPresented = true
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(storeKitManager.isPurchasing || storeKitManager.isRestoring)
                        Button("Terms of Use") {
                            openURL(AppConstants.Links.termsOfUse)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "A5ADBA"))
                    .padding(.top, 15)
                    .padding(.bottom,5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            .clipped()

            .background(Color(hex: "F2F3F5").ignoresSafeArea())
            .task {
                await storeKitManager.loadProductsIfNeeded()
                await storeKitManager.refreshEntitlementStatus()
            }
            .onChange(of: storeKitManager.productsByID.keys.sorted(), initial: true) { _, _ in
                selectAvailablePlan()
            }
            .alert("Store", isPresented: $isStoreAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(storeAlertMessage)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private var isStoreBusy: Bool {
        storeKitManager.isLoadingProducts || storeKitManager.isPurchasing || storeKitManager.isRestoring
    }

    private var isSelectedPlanAvailable: Bool {
        storeKitManager.productsByID[selectedPlan.productID] != nil
    }

    private var purchaseButtonTitle: String {
        if storeKitManager.isPurchasing { return "Waiting for App Store…" }
        if storeKitManager.isRestoring { return "Restoring purchases…" }
        if storeKitManager.isLoadingProducts { return "Loading plans…" }
        return isSelectedPlanAvailable ? "Continue" : "Retry loading plans"
    }

    private var purchaseButton: some View {
        Button {
            let productID = selectedPlan.productID
            Task {
                guard storeKitManager.productsByID[productID] != nil else {
                    await storeKitManager.loadProducts()
                    return
                }
                let success = await storeKitManager.purchase(productID: productID)
                if success {
                    hasUnlockedPro = true
                    onContinue()
                } else if let message = storeKitManager.latestErrorMessage {
                    storeAlertMessage = message
                    isStoreAlertPresented = true
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isStoreBusy {
                    ProgressView()
                        .tint(.white)
                }
                Text(purchaseButtonTitle)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient(
                    colors: [Color(hex: "FF2450"), Color(hex: "FF002B")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color(hex: "FF0A3D").opacity(0.25), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(storeKitManager.isLoadingProducts || storeKitManager.isPurchasing || storeKitManager.isRestoring)
        .accessibilityIdentifier("paywall.continue")
    }

    @ViewBuilder
    private var productLoadingError: some View {
        if let message = storeKitManager.productLoadErrorMessage {
            VStack(spacing: 4) {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "FF0A3D"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("paywall.productsError")

                if isSelectedPlanAvailable {
                    Button("Retry loading plans") {
                        Task { await storeKitManager.loadProducts() }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .disabled(isStoreBusy)
                    .accessibilityIdentifier("paywall.retry")
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 8)
        }
    }

    private func selectAvailablePlan() {
        guard !isSelectedPlanAvailable else { return }
        if let plan = [SubscriptionPlan.yearly, .monthly, .weekly].first(where: {
            storeKitManager.productsByID[$0.productID] != nil
        }) {
            selectedPlan = plan
        }
    }
}

private struct PaywallHeroView: View {
    var body: some View {
        Image("app_bg_paywalls")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .clipped()
    }
}

private struct PaywallPlanCard: View {
    let plan: SubscriptionPlan
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(hex: "F7F8FA"))
            .frame(height: 60)
            .overlay {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(isSelected ? Color(hex: "FF0A3D") : .clear, lineWidth: 2)
            }
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: "3C4350"))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "A4ACB8"))
                }
                .padding(.leading, 16)
                .offset(y: 1)
            }
            .overlay(alignment: .trailing) {
                if plan == .yearly {
                    Capsule()
                        .fill(isSelected ? Color(hex: "FF0A3D") : Color(hex: "FFCFDA"))
                        .frame(width: 80, height: 24)
                        .overlay(
                            Text("BEST OFFER")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .padding(.trailing, 14)
                }
            }
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
    }
}

private enum SubscriptionPlan: CaseIterable {
    case weekly
    case monthly
    case yearly

    var productID: String {
        switch self {
        case .weekly:
            return AppConstants.Store.weeklyProductID
        case .monthly:
            return AppConstants.Store.monthlyProductID
        case .yearly:
            return AppConstants.Store.yearlyProductID
        }
    }

    var periodSuffix: String {
        switch self {
        case .weekly:
            return "week"
        case .monthly:
            return "month"
        case .yearly:
            return "year"
        }
    }

    var title: String {
        switch self {
        case .weekly:
            return "Weekly Access"
        case .monthly:
            return "Monthly Access"
        case .yearly:
            return "Yearly Access"
        }
    }

}
