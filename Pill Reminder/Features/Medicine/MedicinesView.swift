import SwiftUI

struct MedicinesView: View {
    @Environment(\.deviceSize) private var deviceSize
    let medications: [Medication]
    var onMedicationTap: (Medication) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Medicines")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(hex: "232833"))
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)

            HStack {
                Text("\(activeCount) active, \(completedCount) completed, \(inactiveCount) unactive")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "8E97A6"))
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 2)

            if medications.isEmpty {
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

                    Text("No medicines added yet")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(hex: "99A1AF"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(medications) { medication in
                            MedicineSummaryCard(
                                medication: medication,
                                status: status(for: medication)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onMedicationTap(medication)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 140)
                }
            }
        }
    }

    private var activeCount: Int {
        medications.filter { status(for: $0) == .active }.count
    }

    private var completedCount: Int {
        medications.filter { status(for: $0) == .completed }.count
    }

    private var inactiveCount: Int {
        medications.filter { status(for: $0) == .inactive }.count
    }

    private func status(for medication: Medication) -> MedicineStatus {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: medication.startDate)
        let end = calendar.startOfDay(for: medication.endDate)

        if today < start {
            return .inactive
        }

        if today > end {
            return .completed
        }

        return .active
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
}

private struct MedicineSummaryCard: View {
    let medication: Medication
    let status: MedicineStatus

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(hex: "FFFFFF").opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(hex: "FFFFFF"), lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                HStack(spacing: 12) {
                    Image("app_ic_pill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(medication.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "2D3440"))
                    }

                    Spacer()

                    Text(status.title)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(status.textColor)
                        .padding(.horizontal, 16)
                        .frame(height: 24)
                        .background(status.backgroundColor)
                        .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: "ACB4C2"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 90)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

private enum MedicineStatus {
    case active
    case completed
    case inactive

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        case .inactive:
            return "Inactive"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .active:
            return Color(hex: "10AF3D")
        case .completed:
            return Color(hex: "D7DCE4")
        case .inactive:
            return Color(hex: "ECEFF4")
        }
    }

    var textColor: Color {
        switch self {
        case .active:
            return .white
        case .completed:
            return Color(hex: "687283")
        case .inactive:
            return Color(hex: "8E97A6")
        }
    }
}

#Preview("Medicines Empty") {
    MedicinesView(medications: [])
}

#Preview("Medicines Filled") {
    MedicinesView(
        medications: [
            Medication(name: "Aspirin", dosage: "100mg", startDate: Date(), durationDays: 7, intervalMinutes: 720),
            Medication(name: "Vitamin D", dosage: "2000 IU", startDate: Date(), durationDays: 30, intervalMinutes: 1440)
        ]
    )
}
