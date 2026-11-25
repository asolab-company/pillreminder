import Foundation

struct PulseProfile: Codable {
    enum Sex: String, CaseIterable, Codable {
        case female = "Female"
        case male = "Male"
        case another = "Another option"
    }

    enum Field: String, CaseIterable {
        case height = "Height", weight = "Weight", age = "Age"

        var key: WritableKeyPath<PulseProfile, Int?> {
            switch self {
            case .height: \.heightCM
            case .weight: \.weightKG
            case .age: \.age
            }
        }

        var range: ClosedRange<Int> {
            switch self {
            case .height: 50...250
            case .weight: 10...350
            case .age: 1...120
            }
        }

        var unit: String {
            switch self {
            case .height: "cm"
            case .weight: "kg"
            case .age: "years"
            }
        }

        func accepts(_ text: String) -> Bool {
            text.isEmpty || (Int(text).map(range.contains) ?? false)
        }
    }

    static let storageKey = "pulseJournal.profile.v1"
    var sex: Sex?
    var age: Int?
    var heightCM: Int?
    var weightKG: Int?

    var hasDetails: Bool { sex != nil || heightCM != nil || weightKG != nil || age != nil }

    var bmi: Double? {
        guard let heightCM, heightCM > 0, let weightKG, weightKG > 0 else { return nil }
        let metres = Double(heightCM) / 100
        return Double(weightKG) / (metres * metres)
    }

    static func load() -> Self {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let profile = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return profile
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
