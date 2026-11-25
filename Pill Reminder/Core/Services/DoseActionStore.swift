import Foundation

enum DoseActionStore {
    private static let storageKey = "mainDoseActionsV1"

    enum Value: String, Codable {
        case taken
        case missed
    }

    private static func makeKey(medicationCreatedAt: Date, scheduledAt: Date) -> String {
        let medicationKey = String(Int(medicationCreatedAt.timeIntervalSince1970))
        let scheduledKey = String(Int(scheduledAt.timeIntervalSince1970))
        return "\(medicationKey)_\(scheduledKey)"
    }

    private static func load() -> [String: Value] {
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

    private static func save(_ actions: [String: Value]) {
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
    }

    static func removeAll() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

}
