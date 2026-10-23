import SwiftUI

struct MainCalendarPickerOverlay: View {
    private let calendar: Calendar
    private let onClose: () -> Void
    private let onApply: (Date) -> Void

    @State private var selectedDate: Date
    @State private var displayedMonth: Date

    init(
        initialDate: Date,
        onClose: @escaping () -> Void,
        onApply: @escaping (Date) -> Void,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.calendar = calendar
        self.onClose = onClose
        self.onApply = onApply

        let startOfMonth =
            calendar.date(
                from: calendar.dateComponents(
                    [.year, .month],
                    from: initialDate
                )
            ) ?? initialDate

        _selectedDate = State(initialValue: initialDate)
        _displayedMonth = State(initialValue: startOfMonth)
    }

    var body: some View {
        VStack {
            calendarCard
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F1F3F6"))
                        Circle()
                            .stroke(Color(hex: "FFD5DF"), lineWidth: 1)
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "8C94A3"))
                    }
                    .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }

            Text(Self.monthFormatter.string(from: displayedMonth))
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color(hex: "2D3440"))
                .padding(.top, 8)

            HStack(spacing: 0) {
                ForEach(Self.weekdayTitles, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "AAB1BD"))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 18)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 0),
                    count: 7
                ),
                spacing: 10
            ) {
                ForEach(Array(dayItems.enumerated()), id: \.offset) {
                    _,
                    dayDate in
                    if let dayDate {
                        Button {
                            selectedDate = dayDate
                        } label: {
                            ZStack {
                                if calendar.isDate(
                                    dayDate,
                                    inSameDayAs: selectedDate
                                ) {
                                    Circle()
                                        .fill(Color(hex: "FF0A3D"))
                                }

                                Text(
                                    "\(calendar.component(.day, from: dayDate))"
                                )
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(
                                    calendar.isDate(
                                        dayDate,
                                        inSameDayAs: selectedDate
                                    )
                                        ? .white : Color(hex: "2D3440")
                                )
                            }
                            .frame(width: 38, height: 38)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(height: 38)
                    }
                }
            }
            .padding(.top, 12)

            Button {
                onApply(selectedDate)
            } label: {
                Text("Apply")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: "FF2450"), Color(hex: "FF002B"),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(
                        color: Color(hex: "FF0A3D").opacity(0.25),
                        radius: 8,
                        y: 3
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(hex: "F8F8FA"))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color(hex: "E8EAF0"), lineWidth: 1)
                )
        )
        .frame(maxWidth: 560)
    }

    private var dayItems: [Date?] {
        guard
            let monthStart = calendar.date(
                from: calendar.dateComponents(
                    [.year, .month],
                    from: displayedMonth
                )
            ),
            let daysRange = calendar.range(
                of: .day,
                in: .month,
                for: monthStart
            )
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingSlots = firstWeekday - 1
        var items = [Date?](repeating: nil, count: leadingSlots)

        for day in daysRange {
            if let date = calendar.date(
                byAdding: .day,
                value: day - 1,
                to: monthStart
            ) {
                items.append(date)
            }
        }

        return items
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let weekdayTitles = [
        "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT",
    ]
}
