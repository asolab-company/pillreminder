import Foundation

enum PulsePeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case quarter = "3 months"
    case year = "Year"

    func interval(containing date: Date, calendar: Calendar) -> DateInterval {
        let component: Calendar.Component = switch self {
        case .week: .weekOfYear
        case .month, .quarter: .month
        case .year: .year
        }
        let interval = calendar.dateInterval(of: component, for: date)!
        guard self == .quarter else { return interval }
        let month = calendar.component(.month, from: interval.start)
        let start = calendar.date(byAdding: .month, value: -((month - 1) % 3), to: interval.start)!
        return DateInterval(start: start, end: calendar.date(byAdding: .month, value: 3, to: start)!)
    }

    func previous(to interval: DateInterval, calendar: Calendar) -> DateInterval {
        self.interval(containing: interval.start.addingTimeInterval(-1), calendar: calendar)
    }
}

struct PulseTrendSummary {
    struct Point: Identifiable {
        let date: Date
        let bpm: Int
        var id: Date { date }
    }

    let interval: DateInterval
    let points: [Point]
    let count: Int
    let lowest: Int?
    let highest: Int?
    let average: Int?
    let change: Int?

    init(entries: [PulseMeasurementEntry], period: PulsePeriod, anchor: Date, calendar: Calendar) {
        let current = period.interval(containing: anchor, calendar: calendar)
        let previous = period.previous(to: current, calendar: calendar)
        interval = current
        let readings = entries.filter { current.start <= $0.measuredAt && $0.measuredAt < current.end }
        let prior = entries.filter { previous.start <= $0.measuredAt && $0.measuredAt < previous.end }
        let values = readings.map(\.bpm)
        count = values.count
        lowest = values.min()
        highest = values.max()
        let mean = Self.mean(values)
        average = mean
        if let mean, let before = Self.mean(prior.map(\.bpm)) {
            change = mean - before
        } else {
            change = nil
        }

        let buckets = Dictionary(grouping: readings) { entry in
            if period == .year {
                return calendar.dateInterval(of: .month, for: entry.measuredAt)!.start
            }
            return calendar.startOfDay(for: entry.measuredAt)
        }
        points = buckets.map { date, group in
            Point(date: date, bpm: Self.mean(group.map(\.bpm))!)
        }.sorted { $0.date < $1.date }
    }

    private static func mean(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}
