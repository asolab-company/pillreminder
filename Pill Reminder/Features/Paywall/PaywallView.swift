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
                            PaywallPlanCard(
                                plan: plan,
                                subtitle: storeKitManager.priceText(
                                    for: plan.productID,
                                    periodSuffix: plan.periodSuffix
                                ),
                                isSelected: selectedPlan == plan
                            )
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    selectedPlan = plan
                                }
                            }
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

                    Button {
                        Task {
                            let success = await storeKitManager.purchase(productID: selectedPlan.productID)
                            if success {
                                hasUnlockedPro = true
                                onContinue()
                            } else if let message = storeKitManager.latestErrorMessage {
                                storeAlertMessage = message
                                isStoreAlertPresented = true
                            }
                        }
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .bold))
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
                    .disabled(storeKitManager.isPurchasing || storeKitManager.isRestoring)
                    .opacity((storeKitManager.isPurchasing || storeKitManager.isRestoring) ? 0.8 : 1)
                    .padding(.horizontal, 26)
                    .padding(.top, 14)

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
            .alert("Store", isPresented: $isStoreAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(storeAlertMessage)
            }
        }
        .ignoresSafeArea(edges: .top)
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

private struct NotificationBannerMock: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(hex: "DBE0E8").opacity(0.96))
            .frame(width: 348, height: 66)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("PILL REMINDER")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color(hex: "6B7383"))
                        Spacer()
                        Text("1m ago")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color(hex: "7A8393"))
                    }
                    Text("Medicine Reminder")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "2D3440"))
                    Text("Time to take: Aspirin")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "39404D"))
                }
                .padding(.horizontal, 12)
            }
            .overlay(alignment: .leading) {
                ZStack {
                    Circle().fill(Color(hex: "FF0A3D"))
                    Image(systemName: "pills.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 14, height: 14)
                .padding(.leading, 6)
                .padding(.top, 6)
            }
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

#Preview("Paywall") {
    PaywallView(onContinue: {}, onSkip: {})
        .environmentObject(StoreKitManager())
}
