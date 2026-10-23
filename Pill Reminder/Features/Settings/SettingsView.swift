import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @AppStorage("hasUnlockedPro") private var hasUnlockedPro = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.startDate, order: .forward) private var medications: [Medication]

    @State private var isDeleteAlertPresented = false
    @State private var isStoreAlertPresented = false
    @State private var storeAlertMessage = ""
    @State private var isPaywallPresented = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(hex: "232833"))
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if !hasProAccess {
                        ProVersionCard {
                            isPaywallPresented = true
                        }
                        .padding(.top, 18)
                    }

                    Text("Support & Legal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "2F3642"))
                        .padding(.top, 4)

                    SettingsActionRow(
                        icon: "shield.fill",
                        title: "Privacy",
                        iconColor: Color(hex: "AAB1BD"),
                        titleColor: Color(hex: "2F3642")
                    ) {
                        openURL(AppConstants.Links.privacyPolicy)
                    }

                    SettingsActionRow(
                        icon: "document.fill",
                        title: "Terms and Conditions",
                        iconColor: Color(hex: "AAB1BD"),
                        titleColor: Color(hex: "2F3642")
                    ) {
                        openURL(AppConstants.Links.termsOfUse)
                    }

                    Text("General")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "2F3642"))
                        .padding(.top, 4)

                    ShareLink(
                        item: AppConstants.Links.appStore,
                        subject: Text("Pill Reminder"),
                        message: Text(AppConstants.Links.shareMessage)
                    ) {
                        SettingsActionRowLabel(
                            icon: "square.and.arrow.up.fill",
                            title: "Share app",
                            iconColor: Color(hex: "AAB1BD"),
                            titleColor: Color(hex: "2F3642")
                        )
                    }
                    .buttonStyle(.plain)

                    SettingsActionRow(
                        icon: "star.fill",
                        title: "Rate Us",
                        iconColor: Color(hex: "AAB1BD"),
                        titleColor: Color(hex: "2F3642")
                    ) {
                        openURL(AppConstants.Links.appStoreReview)
                    }

                    if !hasProAccess {
                        SettingsActionRow(
                            icon: "clock.arrow.circlepath",
                            title: "Restore",
                            iconColor: Color(hex: "AAB1BD"),
                            titleColor: Color(hex: "2F3642")
                        ) {
                            Task {
                                let success = await storeKitManager.restorePurchases()
                                if success {
                                    hasUnlockedPro = true
                                    storeAlertMessage = "Purchases restored successfully."
                                } else {
                                    storeAlertMessage = storeKitManager.latestErrorMessage ?? "No active purchases were found."
                                }
                                isStoreAlertPresented = true
                            }
                        }
                    }

                    SettingsActionRow(
                        icon: "trash.fill",
                        title: "Delete Data",
                        iconColor: Color(hex: "FF2F55"),
                        titleColor: Color(hex: "2F3642")
                    ) {
                        isDeleteAlertPresented = true
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .alert("Delete all data?", isPresented: $isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This will remove all medicines and history from local database.")
        }
        .alert("Store", isPresented: $isStoreAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(storeAlertMessage)
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            PaywallView(
                onContinue: {
                    hasUnlockedPro = true
                    isPaywallPresented = false
                },
                onSkip: {
                    isPaywallPresented = false
                }
            )
            .environmentObject(storeKitManager)
        }
    }

    private func deleteAllData() {
        for medication in medications {
            modelContext.delete(medication)
        }

        try? modelContext.save()
        DoseActionStore.removeAll()

        UserDefaults.standard.removeObject(forKey: "hasRatedApp")
        UserDefaults.standard.removeObject(forKey: "successfulMedicineAddsCount")
        UserDefaults.standard.removeObject(forKey: "lastRatingPromptAt")
        UserDefaults.standard.removeObject(forKey: "ratingPromptSnoozeUntil")

        Task {
            await MedicationReminderScheduler.shared.removeAllMedicationRequests()
        }
    }

    private var hasProAccess: Bool {
        hasUnlockedPro || storeKitManager.hasActiveSubscription
    }
}

private struct ProVersionCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {

                    Image("app_ic_crown")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 58, height: 58)

                Text("PRO Version")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .frame(height: 84)
            .background(
                LinearGradient(
                    colors: [Color(hex: "FF2450"), Color(hex: "FF002B")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color(hex: "FF0A3D").opacity(0.2), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsActionRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    let titleColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsActionRowLabel(
                icon: icon,
                title: title,
                iconColor: iconColor,
                titleColor: titleColor
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsActionRowLabel: View {
    let icon: String
    let title: String
    let iconColor: Color
    let titleColor: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(hex: "FFFFFF").opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(hex: "FFFFFF"), lineWidth: 1)
            }
            .overlay {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "F2F2F2"))
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(iconColor)
                    }
                    .frame(width: 40, height: 40)

                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(titleColor)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: "AAB1BD"))
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 66)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}
