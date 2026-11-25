import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreKitManager
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedID = AppConstants.Store.weeklyProductID
    @State private var trialProductID: String?
    @State private var trialTitle = ""
    @State private var alertMessage: String?
    @State private var completed = false
    let onContinue: () -> Void
    let onSkip: () -> Void

    private var selectedProduct: Product? { store.productsByID[selectedID] }
    private var hasTrial: Bool { selectedProduct != nil && trialProductID == selectedID }
    private var busy: Bool { store.isPurchasing || store.isRestoring || store.isLoadingProducts }
    private var availableIDs: [String] { AppConstants.Store.productIDs.filter { store.productsByID[$0] != nil } }

    var body: some View {
        GeometryReader { proxy in
            let tight = proxy.size.height < 720
            let heroHeight = min(306, max(155, proxy.size.height * (tight ? 0.29 : 0.32)))
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: tight ? 11 : 16) {
                        PulsePaywallHero(contentHeight: heroHeight, topInset: proxy.safeAreaInsets.top)
                        VStack(spacing: 7) {
                            VStack(spacing: 0) {
                                Text("Track Your Pulse.").foregroundStyle(PulseStyle.accent)
                                Text("Know Your Heart.").foregroundStyle(PulseStyle.secondary)
                            }
                            .font(tight ? .title.bold() : .largeTitle.bold())
                            .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
                            Text("Check your pulse, follow your trends and share your readings with your doctor.")
                                .font(.subheadline).frame(maxWidth: 390)
                        }
                        .multilineTextAlignment(.center).padding(.horizontal, 20)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                            feature("Instant pulse", "Measure your heart rate with the camera.", icon: "heart.text.square")
                            feature("Trends & history", "See how your pulse changes over time.", icon: "chart.xyaxis.line")
                            feature("Pulse reports", "Share your readings as a PDF or CSV.", icon: "doc.text")
                            offer
                        }
                        .padding(.horizontal, 18)
                        if let message = store.productLoadErrorMessage {
                            Text(message).font(.footnote).foregroundStyle(PulseStyle.secondary)
                                .multilineTextAlignment(.center).padding(.horizontal, 20)
                                .accessibilityIdentifier("paywall.productsError")
                        }
                    }
                    .frame(maxWidth: 570).frame(maxWidth: .infinity).padding(.bottom, 10)
                }
                .scrollBounceBehavior(.basedOnSize)
                .ignoresSafeArea(.container, edges: .top)
                footer
            }
        }
        .foregroundStyle(PulseStyle.primaryText)
        .background(PulseStyle.background.ignoresSafeArea())
        .task { await store.loadProductsIfNeeded() }
        .onAppear { PulseAnalytics.shared.track("paywall_viewed") }
        .onChange(of: availableIDs, initial: true) { _, ids in
            if !ids.contains(selectedID), let first = ids.first { selectedID = first }
        }
        .task(id: selectedProduct?.id) {
            trialProductID = nil
            guard let product = selectedProduct, let subscription = product.subscription,
                  let intro = subscription.introductoryOffer, intro.paymentMode == .freeTrial,
                  await subscription.isEligibleForIntroOffer, !Task.isCancelled else { return }
            trialTitle = "\(intro.period.value * intro.periodCount)-\(unit(intro.period.unit)) free trial"
            trialProductID = product.id
        }
        .onChange(of: store.hasActiveSubscription) { _, active in if active { finish() } }
        .alert("Store", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(alertMessage ?? "") }
    }

    private var offer: some View {
        let name = hasTrial ? trialTitle : planName(selectedID)
        let price = selectedProduct.map { (hasTrial ? "Then " : "") + billing(for: $0) }
            ?? (store.isLoadingProducts ? "Loading price…" : "Price unavailable")
        return Group {
            if availableIDs.count > 1 {
                Menu {
                    ForEach(availableIDs, id: \.self) { id in
                        if let product = store.productsByID[id] {
                            Button {
                                selectedID = id
                            } label: {
                                let label = "\(planName(id)) · \(billing(for: product))"
                                if id == selectedID { Label(label, systemImage: "checkmark") }
                                else { Text(label) }
                            }
                            .accessibilityIdentifier("paywall.plan.\(id)")
                        }
                    }
                } label: { feature(name, price, icon: "calendar", isOffer: true, canChoose: true) }
                .accessibilityHint("Choose a subscription plan")
            } else {
                feature(name, price, icon: "calendar", isOffer: true)
            }
        }
        .buttonStyle(.plain).accessibilityIdentifier("paywall.offer")
    }

    private func feature(_ title: String, _ detail: String, icon: String, isOffer: Bool = false, canChoose: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseStyle.accent)
                    .frame(width: 29, height: 29).background(PulseStyle.accentTint, in: Circle())
                    .accessibilityHidden(true)
                Text(title).font(.subheadline.bold()).fixedSize(horizontal: false, vertical: true)
                if canChoose { Image(systemName: "chevron.down").font(.caption2).accessibilityHidden(true) }
            }
            Text(detail).font(.footnote).foregroundStyle(PulseStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12).frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 21))
        .shadow(color: isOffer ? PulseStyle.accent.opacity(0.16) : .black.opacity(0.045), radius: isOffer ? 9 : 5, y: 3)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Label("Cancel anytime", systemImage: "checkmark.circle").font(.footnote.bold()).foregroundStyle(PulseStyle.accent)
            Button {
                Task {
                    if selectedProduct == nil {
                        await store.loadProducts()
                    } else if await store.purchase(productID: selectedID) {
                        finish()
                    } else {
                        alertMessage = store.latestErrorMessage
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    if busy { ProgressView().tint(.white) }
                    Text(actionTitle)
                }
            }
            .buttonStyle(PulsePrimaryButton()).disabled(busy)
            .accessibilityIdentifier("paywall.continue")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) { legalActions }
                VStack(spacing: 0) { legalActions }
            }
            .font(.caption.weight(.medium)).foregroundStyle(PulseStyle.secondary)
        }
        .frame(maxWidth: 500)
        .padding(.top, 5).padding(.horizontal, 18)
    }

    @ViewBuilder private var legalActions: some View {
        Link(destination: AppConstants.Links.privacyPolicy) { legalLabel("Privacy Policy") }
        Button {
            PulseAnalytics.shared.track("paywall_skipped")
            onSkip()
        } label: { legalLabel("Skip") }
        .disabled(store.isPurchasing || store.isRestoring)
        Button {
            Task {
                if await store.restorePurchases() { finish() }
                else { alertMessage = store.latestErrorMessage }
            }
        } label: { legalLabel("Restore") }
        .disabled(store.isPurchasing || store.isRestoring)
        Link(destination: AppConstants.Links.termsOfUse) { legalLabel("Terms of Use") }
    }

    private func legalLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
    }

    private var actionTitle: String {
        if store.isPurchasing { return "Purchasing…" }
        if store.isRestoring { return "Restoring…" }
        if store.isLoadingProducts { return "Loading plans…" }
        guard selectedProduct != nil else { return "Retry loading plans" }
        return hasTrial ? "Start Free Trial" : "Subscribe"
    }

    private func finish() {
        guard store.hasActiveSubscription, !completed else { return }
        completed = true
        onContinue()
    }

    private func planName(_ id: String) -> String {
        switch id {
        case AppConstants.Store.weeklyProductID: "Weekly plan"
        case AppConstants.Store.monthlyProductID: "Monthly plan"
        default: "Yearly plan"
        }
    }

    private func billing(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        let name = unit(period.unit)
        return period.value == 1 ? "\(product.displayPrice) per \(name)" : "\(product.displayPrice) every \(period.value) \(name)s"
    }

    private func unit(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        @unknown default: "period"
        }
    }
}
