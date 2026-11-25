import SwiftUI
import SwiftData

struct MainMenuView: View {
    private enum Tab { case history, settings }
    private enum Cover: Int, Identifiable {
        case scanner, scannerPaywall, historyPaywall
        var id: Int { rawValue }
    }

    @EnvironmentObject private var store: StoreKitManager
    @Environment(\.scenePhase) private var scenePhase
    @Query private var medications: [Medication]
    @State private var tab: Tab = .history
    @State private var cover: Cover?
    @State private var scanAfterPurchase = false
    @State private var entries: [PulseMeasurementEntry] = []

    var body: some View {
        Group {
            switch tab {
            case .history:
                if store.hasActiveSubscription {
                    PulseHistoryView(entries: entries, onDelete: { entries = PulseMeasurementStore.delete($0) })
                        .onAppear { entries = PulseMeasurementStore.load() }
                } else {
                    PulseHistoryProView { cover = .historyPaywall }
                }
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PulseStyle.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                tabButton(.history, label: "History", symbol: "clock.arrow.circlepath")
                Button(action: startMeasurement) {
                    PulseTabHeart()
                        .frame(width: 60, height: 60)
                        .background(PulseStyle.actionGradient, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Measure pulse")
                .accessibilityIdentifier("pulse.measure")
                .accessibilityShowsLargeContentViewer { Label("Measure pulse", systemImage: "heart.fill") }
                tabButton(.settings, label: "Settings", symbol: "gearshape")
            }
            .padding(.vertical, 6)
            .background(.white)
            .overlay(alignment: .top) { Divider() }
        }
        .fullScreenCover(item: $cover, onDismiss: {
            if scanAfterPurchase {
                scanAfterPurchase = false
                startMeasurement()
            }
        }) { destination in
            switch destination {
            case .scanner:
                PulseReaderView { entry in entries = PulseMeasurementStore.add(entry) }
            case .scannerPaywall, .historyPaywall:
                PaywallView(onContinue: {
                    scanAfterPurchase = destination == .scannerPaywall
                    cover = nil
                }, onSkip: { cover = nil })
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, !medications.isEmpty else { return }
            await MedicationReminderScheduler.shared.syncSchedules(for: medications.map(\.reminderPayload))
        }
    }

    private func startMeasurement() {
        tab = .history
        cover = store.hasActiveSubscription ? .scanner : .scannerPaywall
    }

    private func tabButton(_ target: Tab, label: String, symbol: String) -> some View {
        Button {
            tab = target
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3.weight(.medium))
                Text(label).font(.caption.weight(.semibold))
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
        .foregroundStyle(tab == target ? PulseStyle.accent : PulseStyle.secondary)
        .buttonStyle(.plain)
        .accessibilityAddTraits(tab == target ? .isSelected : [])
        .accessibilityIdentifier("tab.\(label)")
        .accessibilityShowsLargeContentViewer { Label(label, systemImage: symbol) }
    }
}

private struct PulseTabHeart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let heart = Image(systemName: "heart.fill").font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
        if reduceMotion || scenePhase != .active { heart } else {
            heart.keyframeAnimator(initialValue: 1.0, repeating: true) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                CubicKeyframe(1.13, duration: 0.14)
                CubicKeyframe(1, duration: 0.16)
                CubicKeyframe(1.08, duration: 0.12)
                CubicKeyframe(1, duration: 0.20)
                LinearKeyframe(1, duration: 0.80)
            }
        }
    }
}
