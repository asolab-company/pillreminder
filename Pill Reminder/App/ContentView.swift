import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasUnlockedPro") private var hasUnlockedPro = false
    @State private var showAnimatedSplash = true
    @State private var isLaunchPaywallPresented = false

    var body: some View {
        ZStack {
            if showAnimatedSplash {
                AnimatedLaunchSplashView {
                    showAnimatedSplash = false
                }
                .transition(.opacity)
            } else {
                Group {
                    if hasCompletedOnboarding {
                        MainMenuView()
                    } else {
                        OnboardingView {
                            completeOnboardingOnce()
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showAnimatedSplash)
        .onChange(of: showAnimatedSplash) { _, _ in
            presentLaunchPaywallIfNeeded()
        }
        .onChange(of: hasCompletedOnboarding) { _, _ in
            presentLaunchPaywallIfNeeded()
        }
        .onChange(of: storeKitManager.hasActiveSubscription) { _, hasSubscription in
            hasUnlockedPro = hasSubscription
            if hasSubscription {
                isLaunchPaywallPresented = false
            } else {
                presentLaunchPaywallIfNeeded()
            }
        }
        .task {
            await storeKitManager.loadProductsIfNeeded()
            await storeKitManager.refreshEntitlementStatus()

            hasUnlockedPro = storeKitManager.hasActiveSubscription

            presentLaunchPaywallIfNeeded()
        }
        .fullScreenCover(isPresented: $isLaunchPaywallPresented) {
            PaywallView(
                onContinue: {
                    hasUnlockedPro = true
                    isLaunchPaywallPresented = false
                },
                onSkip: {
                    isLaunchPaywallPresented = false
                }
            )
            .environmentObject(storeKitManager)
        }
    }

    private func completeOnboardingOnce() {
        guard !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
    }

    private var hasProAccess: Bool {
        hasUnlockedPro || storeKitManager.hasActiveSubscription
    }

    private func presentLaunchPaywallIfNeeded() {
        guard !showAnimatedSplash else { return }
        guard hasCompletedOnboarding else { return }
        guard !hasProAccess else { return }
        isLaunchPaywallPresented = true
    }
}

#Preview {
    ContentView()
        .environmentObject(StoreKitManager())
}
