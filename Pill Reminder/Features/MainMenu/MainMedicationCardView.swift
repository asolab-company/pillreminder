import SwiftUI

enum MedicationDoseDisplayState {
    case overdue(minutes: Int)
    case upcoming(minutes: Int)
    case taken
    case missed
    case missedPast
    case scheduled
}

struct MainMedicationCardView: View {
    let medication: Medication
    let scheduledDate: Date
    let displayState: MedicationDoseDisplayState
    let onMarkMissed: () -> Void
    let onMarkTaken: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(hex: "FFFFFF").opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(hex: "FFFFFF"), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                VStack(spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        Image("app_ic_pill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 58, height: 58)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(medication.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "232833"))

                            Text(medication.dosage)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(hex: "99A1AF"))

                            Text(statusText)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(statusColor)
                                .lineLimit(1)
                        }

                        Spacer()

                        if shouldShowWarning {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color(hex: "FF0A3D"))
                        }
                    }

                    if shouldShowActions {
                        HStack(spacing: 10) {
                            Button(action: onMarkMissed) {
                                Text("Missed")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color(hex: "FF0A3D"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .overlay {
                                        Capsule()
                                            .stroke(Color(hex: "FF0A3D"), lineWidth: 3)
                                    }
                            }
                            .buttonStyle(.plain)

                            Button(action: onMarkTaken) {
                                Text("Taken")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(hex: "FF2450"), Color(hex: "FF002B")],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }    .padding(.top,7)
                    }
                    
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .frame(height: shouldShowActions ? 146 : 90)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private var shouldShowActions: Bool {
        if case .overdue = displayState {
            return true
        }
        return false
    }

    private var shouldShowWarning: Bool {
        switch displayState {
        case .overdue, .missedPast:
            return true
        case .upcoming, .scheduled, .taken, .missed:
            return false
        }
    }

    private var statusColor: Color {
        switch displayState {
        case .overdue, .missed, .missedPast:
            return Color(hex: "FF0A3D")
        case .upcoming, .taken, .scheduled:
            return Color(hex: "8D97A6")
        }
    }

    private var statusText: String {
        let time = Self.timeFormatter.string(from: scheduledDate)

        switch displayState {
        case .overdue(let minutes):
            return "\(minutes) minutes ago (\(time))"
        case .upcoming(let minutes):
            return "After \(minutes) min (\(time))"
        case .taken:
            return "Taken (\(time))"
        case .missed:
            return "Missed (\(time))"
        case .missedPast:
            return "Missed (\(time))"
        case .scheduled:
            return "At \(time)"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

#Preview("Main Medication Card") {
    let medication = Medication(
        name: "Aspirin",
        dosage: "100mg",
        startDate: Date(),
        durationDays: 7
    )

    return VStack(spacing: 12) {
        MainMedicationCardView(
            medication: medication,
            scheduledDate: Date().addingTimeInterval(-25 * 60),
            displayState: .overdue(minutes: 25),
            onMarkMissed: {},
            onMarkTaken: {}
        )

        MainMedicationCardView(
            medication: medication,
            scheduledDate: Date().addingTimeInterval(12 * 60),
            displayState: .upcoming(minutes: 12),
            onMarkMissed: {},
            onMarkTaken: {}
        )
    }
    .padding()
    .background(Color(hex: "F2F3F5"))
}
