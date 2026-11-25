import Foundation

nonisolated struct PulseMeasurementEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let bpm: Int
    let measuredAt: Date

    init(id: UUID = UUID(), bpm: Int, measuredAt: Date = Date()) {
        self.id = id
        self.bpm = bpm
        self.measuredAt = measuredAt
    }

}

enum PulseMeasurementStore {
    private static let storageKey = "pulseMeasurements"

    static func load() -> [PulseMeasurementEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([PulseMeasurementEntry].self, from: data)
        else {
            return []
        }

        return entries.sorted { $0.measuredAt > $1.measuredAt }
    }

    static func save(_ entries: [PulseMeasurementEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func add(_ entry: PulseMeasurementEntry) -> [PulseMeasurementEntry] {
        let updated = ([entry] + load()).sorted { $0.measuredAt > $1.measuredAt }
        save(updated)
        return updated
    }

    static func delete(_ entry: PulseMeasurementEntry) -> [PulseMeasurementEntry] {
        let updated = load().filter { $0.id != entry.id }
        save(updated)
        return updated
    }
}
