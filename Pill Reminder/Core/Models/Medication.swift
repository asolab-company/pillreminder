import Foundation
import SwiftData
import SwiftUI

@Model
final class Medication {
    var name: String
    var dosage: String
    var startDate: Date
    var durationDays: Int
    var intervalMinutes: Int = 12 * 60
    var endDate: Date
    var createdAt: Date

    init(
        name: String,
        dosage: String,
        startDate: Date,
        durationDays: Int,
        intervalMinutes: Int = 12 * 60,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.dosage = dosage
        self.startDate = startDate
        self.durationDays = durationDays
        self.intervalMinutes = intervalMinutes
        self.endDate = Calendar.current.date(byAdding: .day, value: max(durationDays - 1, 0), to: startDate) ?? startDate
        self.createdAt = createdAt
    }

    func isScheduled(on day: Date, calendar: Calendar = .current) -> Bool {
        let startOfDay = calendar.startOfDay(for: day)
        let startBoundary = calendar.startOfDay(for: startDate)
        let endBoundary = calendar.startOfDay(for: endDate)
        return startOfDay >= startBoundary && startOfDay <= endBoundary
    }
}

#Preview("Medication Model") {
    let medication = Medication(
        name: "Aspirin",
        dosage: "100mg",
        startDate: Date(),
        durationDays: 7,
        intervalMinutes: 720
    )

    return VStack(spacing: 8) {
        Text(medication.name)
            .font(.headline)
        Text(medication.dosage)
            .foregroundStyle(.secondary)
    }
    .padding()
}
