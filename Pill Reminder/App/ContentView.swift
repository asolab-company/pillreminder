import SwiftUI

private enum AppStage {
    case splash
    case onboarding
    case paywall
    case main
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasUnlockedPro") private var hasUnlockedPro = false
    @State private var stage: AppStage = .splash
    @State private var didFinishSplash = false

    var body: some View {
        Group {
            switch stage {
            case .splash:
                AnimatedLaunchSplashView {
                    Task { await finishSplash() }
                }

            case .onboarding:
                OnboardingView {
                    completeOnboardingOnce()
                }

            case .paywall:
                PaywallView(
                    onContinue: {
                        hasUnlockedPro = true
                        stage = .main
                    },
                    onSkip: {
                        stage = .main
                    }
                )
                .environmentObject(storeKitManager)

            case .main:
                MainMenuView()
            }
        }
        .preferredColorScheme(.light)
        .onChange(of: storeKitManager.hasActiveSubscription) { _, hasSubscription in
            hasUnlockedPro = hasSubscription
            guard didFinishSplash else { return }

            if hasSubscription, stage != .main {
                stage = .main
            }
        }
        .onOpenURL { url in
            AppsFlyerService.shared.handleOpen(url: url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            AppsFlyerService.shared.continueUserActivity(activity)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                AppsFlyerService.shared.startRespectingTrackingAuthorization()
            } else if phase == .background {
                AppsFlyerService.shared.sceneDidEnterBackground()
            }
        }
    }

    private func completeOnboardingOnce() {
        guard !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
        stage = .paywall
    }

    @MainActor
    private func finishSplash() async {
        guard !didFinishSplash else { return }
        didFinishSplash = true

        await storeKitManager.refreshEntitlementStatus()
        hasUnlockedPro = storeKitManager.hasActiveSubscription

        if hasUnlockedPro {
            stage = .main
        } else if hasCompletedOnboarding {
            stage = .paywall
        } else {
            stage = .onboarding
        }

        if !hasUnlockedPro {
            Task {
                await storeKitManager.loadProductsIfNeeded()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(StoreKitManager())
}
