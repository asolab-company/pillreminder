import SwiftUI

private enum AppStage: Equatable {
    case splash
    case onboarding
    case paywall
    case main
}

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @AppStorage(AppConstants.Onboarding.completedKey) private var hasCompletedOnboarding = false
    @State private var stage: AppStage = .splash
    @State private var didFinishSplash = false
    @State private var returnedFromBackground = false

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
                        if storeKitManager.hasActiveSubscription { stage = .main }
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.26), value: stage)
        .preferredColorScheme(.light)
        .onChange(of: storeKitManager.hasActiveSubscription) { _, hasSubscription in
            guard didFinishSplash else { return }
            if hasSubscription, stage == .paywall {
                stage = .main
            } else if !hasSubscription, stage == .main {
                stage = .paywall
            }
        }
        .onOpenURL { url in
            guard MetaAppEvents.shared.openWebEntry(url) else { return }
            if hasCompletedOnboarding, stage == .main, !storeKitManager.hasActiveSubscription {
                stage = .paywall
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                MetaAppEvents.shared.didBecomeActive()
                Task { await storeKitManager.retryUnfinishedTransactions() }
                if returnedFromBackground {
                    returnedFromBackground = false
                    if hasCompletedOnboarding, stage == .main, !storeKitManager.hasActiveSubscription {
                        stage = .paywall
                    }
                    Task { await storeKitManager.refreshEntitlementStatus() }
                }
            } else if phase == .background {
                returnedFromBackground = true
            }
        }
    }

    private func completeOnboardingOnce() {
        guard !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
        PulseAnalytics.shared.track("onboarding_completed")
        stage = storeKitManager.hasActiveSubscription ? .main : .paywall
    }

    @MainActor
    private func finishSplash() async {
        guard !didFinishSplash else { return }
        didFinishSplash = true

        Task {
            await storeKitManager.refreshEntitlementStatus()
            showInitialScreen()
        }
        if hasCompletedOnboarding {
            try? await Task.sleep(for: .seconds(2))
        }
        showInitialScreen()
    }

    private func showInitialScreen() {
        guard stage == .splash else { return }
        if hasCompletedOnboarding {
            stage = storeKitManager.hasActiveSubscription ? .main : .paywall
        } else {
            stage = .onboarding
        }

        if !storeKitManager.hasActiveSubscription {
            Task {
                await storeKitManager.loadProductsIfNeeded()
            }
        }
    }
}
