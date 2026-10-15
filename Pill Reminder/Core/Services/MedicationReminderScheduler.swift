import Foundation
import UserNotifications

struct MedicationReminderPayload: Sendable {
    let medicationCreatedAt: Date
    let name: String
    let dosage: String
    let startDate: Date
    let endDate: Date
    let intervalMinutes: Int
}

extension Medication {
    var reminderPayload: MedicationReminderPayload {
        MedicationReminderPayload(
            medicationCreatedAt: createdAt,
            name: name,
            dosage: dosage,
            startDate: startDate,
            endDate: endDate,
            intervalMinutes: intervalMinutes
        )
    }
}

final class MedicationReminderScheduler {
    static let shared = MedicationReminderScheduler()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func configureCategories() {
        let takenAction = UNNotificationAction(
            identifier: Self.takenActionID,
            title: "Taken",
            options: []
        )
        let missedAction = UNNotificationAction(
            identifier: Self.missedActionID,
            title: "Missed",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [takenAction, missedAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    func syncSchedules(for payloads: [MedicationReminderPayload]) async {
        guard await isAuthorizedForScheduling() else { return }

        await removePendingMedicationRequests()

        let now = Date()
        let occurrences = payloads
            .flatMap { reminderOccurrences(for: $0, now: now) }
            .sorted { $0.date < $1.date }
            .prefix(Self.maxPendingRequests)

        for occurrence in occurrences {
            await schedule(occurrence)
        }
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestAuthorization()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func removeAllMedicationRequests() async {
        let pending = await pendingRequests()
        let pendingIDs = pending.map(\.identifier).filter {
            $0.hasPrefix(Self.requestPrefix)
        }
        if !pendingIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        }

        let delivered = await deliveredRequests()
        let deliveredIDs = delivered.map(\.request.identifier).filter {
            $0.hasPrefix(Self.requestPrefix)
        }
        if !deliveredIDs.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        }
    }

    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let doseAction: DoseActionStore.Value
        switch response.actionIdentifier {
        case Self.takenActionID:
            doseAction = .taken
        case Self.missedActionID:
            doseAction = .missed
        default:
            return
        }

        let userInfo = response.notification.request.content.userInfo

        guard
            let createdAtTimestamp = userInfo[Self.userInfoCreatedAtKey] as? Double,
            let scheduledAtTimestamp = userInfo[Self.userInfoScheduledAtKey] as? Double
        else {
            return
        }

        let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        let scheduledAt = Date(timeIntervalSince1970: scheduledAtTimestamp)

        DoseActionStore.set(
            doseAction,
            medicationCreatedAt: createdAt,
            scheduledAt: scheduledAt
        )
    }

    private func reminderOccurrences(
        for payload: MedicationReminderPayload,
        now: Date
    ) -> [ReminderOccurrence] {
        guard payload.intervalMinutes > 0 else { return [] }
        guard payload.endDate >= now else { return [] }

        let interval = TimeInterval(payload.intervalMinutes * 60)
        let start = payload.startDate.addingTimeInterval(interval)
        guard start <= payload.endDate else { return [] }
        var nextDate = start

        if nextDate < now {
            let elapsedIntervals = Int(
                floor(now.timeIntervalSince(start) / interval)
            )
            nextDate = start.addingTimeInterval(TimeInterval(elapsedIntervals) * interval)
            if nextDate < now {
                nextDate = nextDate.addingTimeInterval(interval)
            }
        }

        var result: [ReminderOccurrence] = []
        var current = nextDate
        let safetyCap = Self.maxPendingRequests * 40

        while current <= payload.endDate && result.count < safetyCap {
            result.append(ReminderOccurrence(payload: payload, date: current))
            current = current.addingTimeInterval(interval)
        }

        return result
    }

    private func schedule(_ occurrence: ReminderOccurrence) async {
        let content = UNMutableNotificationContent()
        content.title = occurrence.payload.name
        content.body = "Time to take: \(occurrence.payload.dosage)"
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo = [
            Self.userInfoCreatedAtKey: occurrence.payload.medicationCreatedAt.timeIntervalSince1970,
            Self.userInfoScheduledAtKey: occurrence.date.timeIntervalSince1970,
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: occurrence.date
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let identifier = Self.requestPrefix
            + "_"
            + String(Int(occurrence.payload.medicationCreatedAt.timeIntervalSince1970))
            + "_"
            + String(Int(occurrence.date.timeIntervalSince1970))

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    private func isAuthorizedForScheduling() async -> Bool {
        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await center.notificationSettings()
    }

    private func removePendingMedicationRequests() async {
        let pending = await pendingRequests()
        let ids = pending.map(\.identifier).filter {
            $0.hasPrefix(Self.requestPrefix)
        }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    private func deliveredRequests() async -> [UNNotification] {
        await center.deliveredNotifications()
    }

    private struct ReminderOccurrence {
        let payload: MedicationReminderPayload
        let date: Date
    }

    static let categoryID = "MEDICATION_REMINDER_CATEGORY"
    static let takenActionID = "MEDICATION_TAKEN_ACTION"
    static let missedActionID = "MEDICATION_MISSED_ACTION"
    static let requestPrefix = "MEDICATION_REMINDER"
    static let userInfoCreatedAtKey = "medication_created_at"
    static let userInfoScheduledAtKey = "medication_scheduled_at"
    static let maxPendingRequests = 64
}
