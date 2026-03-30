import Foundation

enum DoseActionStore {
    static let storageKey = "mainDoseActionsV1"

    enum Value: String, Codable {
        case taken
        case missed
    }

    static func makeKey(medicationCreatedAt: Date, scheduledAt: Date) -> String {
        let medicationKey = String(Int(medicationCreatedAt.timeIntervalSince1970))
        let scheduledKey = String(Int(scheduledAt.timeIntervalSince1970))
        return "\(medicationKey)_\(scheduledKey)"
    }

    static func makeLegacyDayKey(medicationCreatedAt: Date, day: Date) -> String {
        let dayKey = dayKeyFormatter.string(from: day)
        let medicationKey = String(Int(medicationCreatedAt.timeIntervalSince1970))
        return "\(medicationKey)_\(dayKey)"
    }

    static func load() -> [String: Value] {
        guard
            let encoded = UserDefaults.standard.string(forKey: storageKey),
            let data = encoded.data(using: .utf8)
        else {
            return [:]
        }

        if let decoded = try? JSONDecoder().decode([String: Value].self, from: data) {
            return decoded
        }

        if let rawDecoded = try? JSONDecoder().decode([String: String].self, from: data) {
            return rawDecoded.compactMapValues(Value.init(rawValue:))
        }

        return [:]
    }

    static func save(_ actions: [String: Value]) {
        guard
            let data = try? JSONEncoder().encode(actions),
            let encoded = String(data: data, encoding: .utf8)
        else {
            return
        }

        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    static func set(
        _ action: Value,
        medicationCreatedAt: Date,
        scheduledAt: Date
    ) {
        var actions = load()
        let key = makeKey(
            medicationCreatedAt: medicationCreatedAt,
            scheduledAt: scheduledAt
        )
        actions[key] = action
        save(actions)
        NotificationCenter.default.post(name: .doseActionsDidChange, object: nil)
    }

    static func removeEntries(forMedicationCreatedAt medicationCreatedAt: Date) {
        var actions = load()
        let prefix = String(Int(medicationCreatedAt.timeIntervalSince1970)) + "_"
        let originalCount = actions.count
        actions = actions.filter { !$0.key.hasPrefix(prefix) }

        guard actions.count != originalCount else { return }
        save(actions)
        NotificationCenter.default.post(name: .doseActionsDidChange, object: nil)
    }

    static func removeAll() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        NotificationCenter.default.post(name: .doseActionsDidChange, object: nil)
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension Notification.Name {
    static let doseActionsDidChange = Notification.Name("doseActionsDidChange")
}
