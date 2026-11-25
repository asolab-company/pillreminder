import Foundation

@MainActor
final class TrialAttribution {
    enum Source: String, Codable { case native, web }

    private struct Attempt: Codable {
        let id: UUID
        let productID: String
        let started: Date
        let source: Source
    }

    private struct State: Codable {
        var webEntry: Date?
        var attempts: [Attempt] = []
        var handled: Set<UInt64> = []
    }

    private let defaults: UserDefaults
    private let key = "meta.trialAttribution.v1"
    private var state: State

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
    }

    static func isWebEntry(_ url: URL, scheme: String?) -> Bool {
        guard let scheme, url.scheme?.lowercased() == scheme.lowercased() else { return false }
        return url.host?.lowercased() == "trial" && url.path == "/web" && url.user == nil && url.port == nil
    }

    func enteredFromWeb(at date: Date = .now) {
        state.webEntry = date
        save()
    }

    func begin(productID: String, at date: Date = .now) -> UUID {
        let webAge = state.webEntry.map { date.timeIntervalSince($0) }
        let source: Source = webAge.map { (0..<86_400).contains($0) } == true ? .web : .native
        if source == .native { state.webEntry = nil }
        state.attempts.removeAll { date.timeIntervalSince($0.started) > 30 * 86_400 }
        let attempt = Attempt(id: UUID(), productID: productID, started: date, source: source)
        state.attempts.append(attempt)
        save()
        return attempt.id
    }

    func cancel(_ id: UUID?) {
        guard let id else { return }
        state.attempts.removeAll { $0.id == id }
        save()
    }

    func consume(
        id: UInt64, productID: String, purchasedAt: Date, isTrial: Bool, attemptID: UUID? = nil
    ) -> Source? {
        guard !state.handled.contains(id) else { return nil }
        let index = state.attempts.lastIndex { attempt in
            guard attempt.productID == productID else { return false }
            if let attemptID, attempt.id != attemptID { return false }
            let age = purchasedAt.timeIntervalSince(attempt.started)
            return (-5...30 * 86_400).contains(age)
        }
        guard let index else { return nil }
        let attempt = state.attempts.remove(at: index)
        if let webEntry = state.webEntry, webEntry <= attempt.started { state.webEntry = nil }
        state.handled.insert(id)
        save()
        return isTrial ? attempt.source : nil
    }

    func clearPending() {
        guard state.webEntry != nil || !state.attempts.isEmpty else { return }
        state.attempts.removeAll()
        state.webEntry = nil
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: key) }
    }
}
