import SwiftUI

struct HistoryTakenEntry: Identifiable {
    let id: String
    let medicationName: String
    let dosage: String
    let takenAt: Date
    let checkColor: Color
}

struct HistoryView: View {
    @Environment(\.deviceSize) private var deviceSize
    let entries: [HistoryTakenEntry]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(hex: "232833"))
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)

            HStack {
                Text("\(takenCount) medications taken")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "8E97A6"))
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 2)

            if entries.isEmpty {
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

                    Text("No history yet")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(hex: "99A1AF"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(entries) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 140)
                }
            }
        }
    }

    private var takenCount: Int {
        entries.count
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

private struct HistoryRow: View {
    let entry: HistoryTakenEntry

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

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.medicationName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "2D3440"))

                        Text(entry.dosage)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(hex: "99A1AF"))

                        Text(Self.dateFormatter.string(from: entry.takenAt))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(hex: "99A1AF"))
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(entry.checkColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 90)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy, HH:mm"
        return formatter
    }()
}

#Preview("History Empty") {
    HistoryView(entries: [])
}

#Preview("History Filled") {
    HistoryView(
        entries: [
            HistoryTakenEntry(
                id: "1",
                medicationName: "Aspirin",
                dosage: "100mg",
                takenAt: Date(),
                checkColor: Color(hex: "FF0A3D")
            ),
            HistoryTakenEntry(
                id: "2",
                medicationName: "Omeprazole",
                dosage: "100mg",
                takenAt: Date().addingTimeInterval(-86400),
                checkColor: Color(hex: "F4B400")
            )
        ]
    )
}

#Preview("History") {
    HistoryView(entries: [])
}
