import SwiftData
import SwiftUI
import UIKit

struct MainMenuView: View {
    @Environment(\.deviceSize) private var deviceSize
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @Query(sort: \Medication.startDate, order: .forward) private
        var medications: [Medication]
    @AppStorage("hasUnlockedPro") private var hasUnlockedPro = false
    @AppStorage("hasRatedApp") private var hasRatedApp = false
    @AppStorage("successfulMedicineAddsCount") private
        var successfulMedicineAddsCount = 0
    @AppStorage("lastRatingPromptAt") private var lastRatingPromptAt: Double = 0
    @AppStorage("ratingPromptSnoozeUntil") private var ratingPromptSnoozeUntil:
        Double = 0
    @State private var selectedTab: MainTab = .list
    @State private var selectedDate = Date()
    @State private var isAddMedicinePresented = false
    @State private var selectedMedicationDetailsItem: MedicationDetailsItem?
    @State private var isRatingPromptPresented = false
    @State private var isCalendarPresented = false
    @State private var isPaywallPresented = false
    @State private var doseActionsByKey: [String: DoseActionStore.Value] = [:]
    @State private var pulseMeasurements: [PulseMeasurementEntry] =
        PulseMeasurementStore.load()
    @State private var isPulseReaderPresented = false
    @State private var shouldOpenPulseAfterPaywall = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                switch selectedTab {
                case .list:
                    listContent
                case .medicines:
                    MedicinesView(
                        medications: medications,
                        onMedicationTap: { medication in
                            selectedMedicationDetailsItem = MedicationDetailsItem(
                                id: medicationIdentity(for: medication),
                                medication: medication
                            )
                        }
                    )
                case .history:
                    HistoryView(entries: historyEntries)
                case .pulse:
                    PulseMeasurementView(
                        entries: pulseMeasurements,
                        onStartMeasurement: {
                            if hasProAccess {
                                isPulseReaderPresented = true
                            } else {
                                shouldOpenPulseAfterPaywall = true
                                isPaywallPresented = true
                            }
                        },
                        onDelete: { entry in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                pulseMeasurements = PulseMeasurementStore.delete(entry)
                            }
                        }
                    )
                case .settings:
                    SettingsView()
                }
            }
            .blur(radius: shouldBlurBackground ? 2.5 : 0)
            .allowsHitTesting(!shouldBlurBackground)

            if isRatingPromptPresented {
                AppRatingPromptView(
                    onClose: {
                        dismissRatingPrompt(withSnoozeDays: 3)
                    },
                    onSubmit: { stars in
                        handleRatingSubmit(stars: stars)
                    }
                )
                .transition(.opacity)
            }

            if isCalendarPresented {
                Color.black.opacity(0.14)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isCalendarPresented = false
                        }
                    }

                MainCalendarPickerOverlay(
                    initialDate: selectedDate,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isCalendarPresented = false
                        }
                    },
                    onApply: { date in
                        selectedDate = date
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isCalendarPresented = false
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            MainMenuTabBar(
                selectedTab: $selectedTab,
                onAdd: {
                    if !hasProAccess && medications.count >= 1 {
                        shouldOpenPulseAfterPaywall = false
                        isPaywallPresented = true
                    } else {
                        isAddMedicinePresented = true
                    }
                },
                onPulse: {
                    if hasProAccess {
                        selectedTab = .pulse
                    } else {
                        shouldOpenPulseAfterPaywall = true
                        isPaywallPresented = true
                    }
                }
            )
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 7)
            .blur(radius: shouldBlurBackground ? 2.5 : 0)
            .allowsHitTesting(!shouldBlurBackground)
        }
        .sheet(isPresented: $isAddMedicinePresented) {
            AddMedicineView(
                defaultDate: selectedDate,
                onSaved: {
                    handleMedicationSaved()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $selectedMedicationDetailsItem) { item in
            MedicationDetailsView(medication: item.medication)
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            PaywallView(
                onContinue: {
                    hasUnlockedPro = true
                    isPaywallPresented = false
                    if shouldOpenPulseAfterPaywall {
                        selectedTab = .pulse
                        shouldOpenPulseAfterPaywall = false
                    }
                },
                onSkip: {
                    isPaywallPresented = false
                    shouldOpenPulseAfterPaywall = false
                }
            )
            .environmentObject(storeKitManager)
        }
        .fullScreenCover(isPresented: $isPulseReaderPresented) {
            PulseReaderView { entry in
                pulseMeasurements = PulseMeasurementStore.add(entry)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isRatingPromptPresented)
        .animation(.easeInOut(duration: 0.18), value: isCalendarPresented)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "F2F3F5").ignoresSafeArea())
        .onAppear {
            loadDoseActions()
            refreshReminderSchedule()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            loadDoseActions()
            refreshReminderSchedule()
        }
        .onChange(of: medications.count) { _, _ in
            refreshReminderSchedule()
        }
        .onReceive(NotificationCenter.default.publisher(for: .doseActionsDidChange)) { _ in
            loadDoseActions()
        }
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Planned")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(hex: "232833"))
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(hex: "F8F8FA"))
                    .frame(height: 72)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color(hex: "FFD5DF"), lineWidth: 1)
                    }
                    .overlay {
                        HStack {
                            Button {
                                shiftDate(by: -1)
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color(hex: "ACB4C2"))
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isCalendarPresented = true
                                }
                            } label: {
                                VStack(spacing: 1) {
                                    Text(
                                        Self.weekdayFormatter.string(
                                            from: selectedDate
                                        )
                                    )
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(Color(hex: "6A7282"))
                                    Text(
                                        Self.headerDateFormatter.string(
                                            from: selectedDate
                                        )
                                    )
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Color(hex: "2D323D"))
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                shiftDate(by: 1)
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color(hex: "ACB4C2"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
            }

            if medicationsForSelectedDate.isEmpty {
                VStack(spacing: 14) {
                    Image("app_ic_empty")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(
                            width: emptyStateImageSize,
                            height: emptyStateImageSize
                        )

                        .opacity(0.2)

                    Text("No medications scheduled for this day")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(hex: "99A1AF"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        let now = Date()
                        ForEach(medicationsForSelectedDate) { medication in
                            let presentation = cardPresentation(
                                for: medication,
                                on: selectedDate,
                                now: now
                            )
                            MainMedicationCardView(
                                medication: medication,
                                scheduledDate: presentation.scheduledDate,
                                displayState: presentation.state,
                                onMarkMissed: {
                                    markDose(
                                        .missed,
                                        for: medication,
                                        scheduledAt: presentation.actionSlotDate
                                    )
                                },
                                onMarkTaken: {
                                    markDose(
                                        .taken,
                                        for: medication,
                                        scheduledAt: presentation.actionSlotDate
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 140)
                }
            }
        }
    }

    private var medicationsForSelectedDate: [Medication] {
        let now = Date()
        return medications
            .filter { medication in
                medication.isScheduled(on: selectedDate)
                    && isCurrentlyActive(medication)
            }
            .sorted { lhs, rhs in
                scheduledDate(for: lhs, on: selectedDate, now: now)
                    < scheduledDate(for: rhs, on: selectedDate, now: now)
            }
    }

    private var historyEntries: [HistoryTakenEntry] {
        let medicationsByCreatedAt = Dictionary(
            uniqueKeysWithValues: medications.map {
                (Int($0.createdAt.timeIntervalSince1970), $0)
            }
        )

        return doseActionsByKey
            .compactMap { key, action in
                guard action == .taken else { return nil }

                let parts = key.split(separator: "_", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return nil }
                guard let createdAtKey = Int(parts[0]) else { return nil }
                guard let medication = medicationsByCreatedAt[createdAtKey] else {
                    return nil
                }

                let takenAt: Date
                if let scheduledTimestamp = Int(parts[1]) {
                    takenAt = Date(timeIntervalSince1970: TimeInterval(scheduledTimestamp))
                } else if let dayDate = Self.historyDayKeyFormatter.date(from: parts[1]) {
                    takenAt = historyTakenDate(for: medication, on: dayDate)
                } else {
                    return nil
                }

                return HistoryTakenEntry(
                    id: key,
                    medicationName: medication.name,
                    dosage: medication.dosage,
                    takenAt: takenAt,
                    checkColor: historyCheckColor(for: medication)
                )
            }
            .sorted { $0.takenAt > $1.takenAt }
    }

    private func isCurrentlyActive(_ medication: Medication) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: medication.startDate)
        let end = calendar.startOfDay(for: medication.endDate)
        return today >= start && today <= end
    }

    private func medicationIdentity(for medication: Medication) -> String {
        String(Int(medication.createdAt.timeIntervalSince1970))
            + "_"
            + medication.name
    }

    private func historyCheckColor(for medication: Medication) -> Color {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: medication.endDate)
        return today > end ? Color(hex: "F4B400") : Color(hex: "FF0A3D")
    }

    private func historyTakenDate(for medication: Medication, on day: Date) -> Date {
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: medication.startDate)

        var combined = DateComponents()
        combined.year = dayComponents.year
        combined.month = dayComponents.month
        combined.day = dayComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = 0

        return calendar.date(from: combined) ?? day
    }

    private var shouldBlurBackground: Bool {
        isRatingPromptPresented || isCalendarPresented
    }

    private var hasProAccess: Bool {
        hasUnlockedPro || storeKitManager.hasActiveSubscription
    }

    private func scheduledDate(for medication: Medication, on day: Date, now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return medication.startDate
        }

        let intervalSeconds = TimeInterval(max(medication.intervalMinutes, 1) * 60)
        let firstReminderDate = medication.startDate.addingTimeInterval(intervalSeconds)
        guard firstReminderDate <= medication.endDate else {
            return firstReminderDate
        }

        let dayEnd = nextDay.addingTimeInterval(-1)
        let upperBound = min(dayEnd, medication.endDate)
        let firstOccurrenceInDay = alignedOccurrenceStart(
            firstReminderDate: firstReminderDate,
            target: max(firstReminderDate, dayStart),
            intervalSeconds: intervalSeconds
        )
        let hasOccurrenceInDay = firstOccurrenceInDay <= upperBound

        if dayStart > now {
            if hasOccurrenceInDay {
                return firstOccurrenceInDay
            }
            let nextOccurrence = alignedOccurrenceStart(
                firstReminderDate: firstReminderDate,
                target: dayStart,
                intervalSeconds: intervalSeconds
            )
            return min(nextOccurrence, medication.endDate)
        }

        if calendar.isDate(day, inSameDayAs: now) {
            if hasOccurrenceInDay {
                if now <= firstOccurrenceInDay {
                    return firstOccurrenceInDay
                }

                let cappedTarget = min(now, upperBound)
                let currentSlot = alignedOccurrenceFloor(
                    firstReminderDate: firstReminderDate,
                    target: cappedTarget,
                    intervalSeconds: intervalSeconds
                )
                return min(max(currentSlot, firstOccurrenceInDay), upperBound)
            }

            let nextOccurrence = alignedOccurrenceStart(
                firstReminderDate: firstReminderDate,
                target: now,
                intervalSeconds: intervalSeconds
            )
            return min(nextOccurrence, medication.endDate)
        }

        if hasOccurrenceInDay {
            return alignedOccurrenceFloor(
                firstReminderDate: firstReminderDate,
                target: upperBound,
                intervalSeconds: intervalSeconds
            )
        }

        return alignedOccurrenceFloor(
            firstReminderDate: firstReminderDate,
            target: min(dayEnd, medication.endDate),
            intervalSeconds: intervalSeconds
        )
    }

    private func cardPresentation(
        for medication: Medication,
        on day: Date,
        now: Date = Date()
    ) -> MedicationCardPresentation {
        let scheduledDate = scheduledDate(for: medication, on: day, now: now)

        if let action = actionForSlot(
            medication: medication,
            scheduledAt: scheduledDate,
            day: day
        ) {
            switch action {
            case .taken:
                let calendar = Calendar.current
                if calendar.isDate(day, inSameDayAs: now),
                   let nextOccurrence = nextUnmarkedOccurrence(
                    for: medication,
                    after: scheduledDate,
                    on: day
                )
                {
                    let minutesDiff = Int(now.timeIntervalSince(nextOccurrence) / 60)
                    if minutesDiff >= 0 {
                        return MedicationCardPresentation(
                            scheduledDate: nextOccurrence,
                            actionSlotDate: scheduledDate,
                            state: .overdue(minutes: minutesDiff)
                        )
                    } else {
                        return MedicationCardPresentation(
                            scheduledDate: nextOccurrence,
                            actionSlotDate: scheduledDate,
                            state: .upcoming(minutes: abs(minutesDiff))
                        )
                    }
                }
                return MedicationCardPresentation(
                    scheduledDate: scheduledDate,
                    actionSlotDate: scheduledDate,
                    state: .taken
                )
            case .missed:
                return MedicationCardPresentation(
                    scheduledDate: scheduledDate,
                    actionSlotDate: scheduledDate,
                    state: .missed
                )
            }
        }

        let calendar = Calendar.current
        let isToday = calendar.isDate(day, inSameDayAs: now)
        let startOfToday = calendar.startOfDay(for: now)
        let startOfSelectedDay = calendar.startOfDay(for: day)

        if isToday {
            let minutesDiff = Int(now.timeIntervalSince(scheduledDate) / 60)
            if minutesDiff >= 0 {
                return MedicationCardPresentation(
                    scheduledDate: scheduledDate,
                    actionSlotDate: scheduledDate,
                    state: .overdue(minutes: minutesDiff)
                )
            } else {
                return MedicationCardPresentation(
                    scheduledDate: scheduledDate,
                    actionSlotDate: scheduledDate,
                    state: .upcoming(minutes: abs(minutesDiff))
                )
            }
        }

        if startOfSelectedDay < startOfToday {
            return MedicationCardPresentation(
                scheduledDate: scheduledDate,
                actionSlotDate: scheduledDate,
                state: .missedPast
            )
        }

        return MedicationCardPresentation(
            scheduledDate: scheduledDate,
            actionSlotDate: scheduledDate,
            state: .scheduled
        )
    }

    private func doseActionKey(for medication: Medication, scheduledAt: Date) -> String {
        DoseActionStore.makeKey(
            medicationCreatedAt: medication.createdAt,
            scheduledAt: scheduledAt
        )
    }

    private func markDose(
        _ action: DoseActionStore.Value,
        for medication: Medication,
        scheduledAt: Date
    ) {
        DoseActionStore.set(
            action,
            medicationCreatedAt: medication.createdAt,
            scheduledAt: scheduledAt
        )
        loadDoseActions()
    }

    private func actionForSlot(
        medication: Medication,
        scheduledAt: Date,
        day: Date
    ) -> DoseActionStore.Value? {
        if let slotAction = slotAction(for: medication, scheduledAt: scheduledAt) {
            return slotAction
        }

        let legacyKey = DoseActionStore.makeLegacyDayKey(
            medicationCreatedAt: medication.createdAt,
            day: day
        )
        return doseActionsByKey[legacyKey]
    }

    private func slotAction(
        for medication: Medication,
        scheduledAt: Date
    ) -> DoseActionStore.Value? {
        let slotKey = doseActionKey(for: medication, scheduledAt: scheduledAt)
        return doseActionsByKey[slotKey]
    }

    private func nextUnmarkedOccurrence(
        for medication: Medication,
        after scheduledAt: Date,
        on day: Date
    ) -> Date? {
        let intervalSeconds = TimeInterval(max(medication.intervalMinutes, 1) * 60)
        var candidate = scheduledAt.addingTimeInterval(intervalSeconds)

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }
        let dayEnd = nextDay.addingTimeInterval(-1)
        let upperBound = min(dayEnd, medication.endDate)

        while candidate <= upperBound {
            if slotAction(for: medication, scheduledAt: candidate) == nil {
                return candidate
            }
            candidate = candidate.addingTimeInterval(intervalSeconds)
        }

        return nil
    }

    private func alignedOccurrenceStart(
        firstReminderDate: Date,
        target: Date,
        intervalSeconds: TimeInterval
    ) -> Date {
        guard target > firstReminderDate else { return firstReminderDate }
        let elapsed = target.timeIntervalSince(firstReminderDate)
        let steps = Int(ceil(elapsed / intervalSeconds))
        return firstReminderDate.addingTimeInterval(TimeInterval(steps) * intervalSeconds)
    }

    private func alignedOccurrenceFloor(
        firstReminderDate: Date,
        target: Date,
        intervalSeconds: TimeInterval
    ) -> Date {
        guard target > firstReminderDate else { return firstReminderDate }
        let elapsed = target.timeIntervalSince(firstReminderDate)
        let steps = Int(floor(elapsed / intervalSeconds))
        return firstReminderDate.addingTimeInterval(TimeInterval(steps) * intervalSeconds)
    }

    private func loadDoseActions() {
        doseActionsByKey = DoseActionStore.load()
    }

    private func refreshReminderSchedule() {
        let payloads = medications.map(\.reminderPayload)
        Task {
            await MedicationReminderScheduler.shared.syncSchedules(for: payloads)
        }
    }

    private var emptyStateImageSize: CGFloat {
        if deviceSize.isExtraSmallDevice {
            return 120
        }

        if deviceSize.isSmallDevice {
            return 136
        }

        return 152
    }

    private func shiftDate(by days: Int) {
        selectedDate =
            Calendar.current.date(byAdding: .day, value: days, to: selectedDate)
            ?? selectedDate
    }

    private func handleMedicationSaved() {
        successfulMedicineAddsCount += 1
        guard shouldShowRatingPrompt else { return }

        lastRatingPromptAt = Date().timeIntervalSince1970
        isRatingPromptPresented = true
    }

    private var shouldShowRatingPrompt: Bool {
        guard !hasRatedApp else { return false }

        let now = Date().timeIntervalSince1970
        guard now >= ratingPromptSnoozeUntil else { return false }

        if successfulMedicineAddsCount == 2 {
            return true
        }

        let addMilestoneReached = successfulMedicineAddsCount % 3 == 0
        let cooldownPassed = now - lastRatingPromptAt >= (24 * 60 * 60)
        return addMilestoneReached && cooldownPassed
    }

    private func dismissRatingPrompt(withSnoozeDays days: Int) {
        isRatingPromptPresented = false
        ratingPromptSnoozeUntil =
            Date().addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
            .timeIntervalSince1970
    }

    private func handleRatingSubmit(stars: Int) {
        guard stars > 0 else { return }
        isRatingPromptPresented = false
        hasRatedApp = true
        openAppStoreReview()
    }

    private func openAppStoreReview() {
        UIApplication.shared.open(AppConstants.Links.appStoreReview)
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private static let historyDayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

}

private struct MedicationDetailsItem: Identifiable {
    let id: String
    let medication: Medication
}

private struct MedicationCardPresentation {
    let scheduledDate: Date
    let actionSlotDate: Date
    let state: MedicationDoseDisplayState
}

private struct MainMenuTabBar: View {
    @Binding var selectedTab: MainTab
    let onAdd: () -> Void
    let onPulse: () -> Void

    var body: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .frame(height: 70)
                .overlay {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.38),
                                    Color.white.opacity(0.08),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                }
                .overlay {
                    Capsule()
                        .stroke(
                            Color(hex: "DDE2EC").opacity(0.7),
                            lineWidth: 0.6
                        )
                }
                .shadow(color: Color.black.opacity(0.1), radius: 5, y: 3)

            HStack(spacing: 0) {
                MainTabItem(
                    icon: "list.bullet",
                    title: "List",
                    isSelected: selectedTab == .list,
                    action: { selectedTab = .list }
                )
                MainTabItem(
                    icon: "pills",
                    title: "Medicines",
                    isSelected: selectedTab == .medicines,
                    action: { selectedTab = .medicines }
                )

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FF0A3D"), Color(hex: "FF0052"),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 54, height: 54)
                        .shadow(
                            color: Color(hex: "FF0A3D").opacity(0.35),
                            radius: 4,
                            y: 3
                        )

                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    onAdd()
                }

                MainTabItem(
                    icon: "heart",
                    title: "Pulse",
                    isSelected: selectedTab == .pulse,
                    action: onPulse
                )
                MainTabItem(
                    icon: "gearshape",
                    title: "Settings",
                    isSelected: selectedTab == .settings,
                    action: { selectedTab = .settings }
                )
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct MainTabItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .frame(width: 28, height: 28, alignment: .center)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(height: 16, alignment: .top)
        }
        .foregroundStyle(
            isSelected ? Color(hex: "FF0A3D") : Color(hex: "9DA5B3")
        )
        .frame(maxWidth: .infinity)
        .frame(height: 52, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

private enum MainTab {
    case list
    case medicines
    case history
    case pulse
    case settings
}
