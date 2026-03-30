import SwiftUI

enum MockScreenStyle {
    case list
    case calendar
    case notification
}

struct HeroBackground: View {
    let style: MockScreenStyle

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "FF2450"), Color(hex: "FF002B")],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "FFEF6B"), Color(hex: "FFEF6B").opacity(0.0)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 185
                    )
                )
                .frame(width: 270, height: 270)
                .offset(x: style == .notification ? 122 : -128, y: -138)

            RoundedRectangle(cornerRadius: 120)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFFFFF").opacity(0.92), Color(hex: "FFD9E8").opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: style == .notification ? 230 : 290, height: style == .notification ? 290 : 210)
                .rotationEffect(.degrees(style == .notification ? -18 : 10))
                .offset(x: style == .calendar ? 80 : -120, y: style == .notification ? 100 : 168)
                .blur(radius: 0.4)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "F8019B").opacity(0.76), Color(hex: "6126FF").opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: style == .calendar ? 270 : 220, height: style == .calendar ? 140 : 108)
                .offset(x: style == .calendar ? 86 : -115, y: 198)
                .blur(radius: 1.2)
        }
    }
}

struct FakeStatusBar: View {
    var body: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.86))

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.84))
        }
    }
}

struct PhoneMock: View {
    let style: MockScreenStyle

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Color.black)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color(hex: "E7E9ED"))
                .padding(6)

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.black)
                    .frame(width: 90, height: 26)
                    .padding(.top, 11)

                Group {
                    switch style {
                    case .list:
                        PlannedScreenMock()
                    case .calendar:
                        CalendarScreenMock()
                    case .notification:
                        NotificationScreenMock()
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)

                Spacer()
            }
        }
        .shadow(color: Color.black.opacity(0.25), radius: 14, y: 8)
    }
}

private struct PlannedScreenMock: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Planned")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "313948"))
                Spacer()
            }

            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .frame(height: 34)
                .overlay(
                    Text("March 11, 2026")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(hex: "6D7788"))
                )

            VStack(spacing: 8) {
                ReminderCard(isActionVisible: true)
                ReminderCard(isActionVisible: true)
                ReminderCard(isActionVisible: false)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReminderCard: View {
    let isActionVisible: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(hex: "F2F4F7"))
            .frame(height: isActionVisible ? 64 : 52)
            .overlay(alignment: .leading) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color(hex: "FF0A3D"))
                        Image(systemName: "pills.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 26, height: 26)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Aspirin")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(hex: "3A4352"))
                        Text("100mg")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(Color(hex: "97A0AE"))
                        if isActionVisible {
                            Text("25 mins ago")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(Color(hex: "FF0A3D"))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
            }
            .overlay(alignment: .bottom) {
                if isActionVisible {
                    HStack(spacing: 6) {
                        Capsule()
                            .stroke(Color(hex: "FF0A3D"), lineWidth: 1)
                            .frame(height: 16)
                            .overlay(
                                Text("Missed")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(Color(hex: "FF0A3D"))
                            )
                        Capsule()
                            .fill(Color(hex: "FF0A3D"))
                            .frame(height: 16)
                            .overlay(
                                Text("Taken")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
    }
}

private struct CalendarScreenMock: View {
    private let rows: [[String]] = [
        ["", "", "", "1", "2", "3", "4"],
        ["5", "6", "7", "8", "9", "10", "11"],
        ["12", "13", "14", "15", "16", "17", "18"],
        ["19", "20", "21", "22", "23", "24", "25"],
        ["26", "27", "28", "29", "30", "31", ""]
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "D2D4D8"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.86))
                .frame(width: 208, height: 260)
                .overlay {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("January 2026")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(hex: "596275"))
                            Spacer()
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(hex: "9BA3B3"))
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.7))
                                .clipShape(Circle())
                        }

                        HStack(spacing: 11) {
                            ForEach(["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"], id: \.self) { day in
                                Text(day)
                                    .font(.system(size: 6, weight: .medium))
                                    .foregroundStyle(Color(hex: "A8AFBC"))
                            }
                        }

                        VStack(spacing: 10) {
                            ForEach(0..<rows.count, id: \.self) { rowIndex in
                                HStack(spacing: 13) {
                                    ForEach(0..<7, id: \.self) { dayIndex in
                                        let day = rows[rowIndex][dayIndex]
                                        ZStack {
                                            if day == "6" {
                                                Circle()
                                                    .fill(Color(hex: "FF0A3D"))
                                                    .frame(width: 22, height: 22)
                                            }
                                            Text(day)
                                                .font(.system(size: 14, weight: day == "6" ? .bold : .medium))
                                                .foregroundStyle(day == "6" ? .white : Color(hex: "4A5161"))
                                        }
                                        .frame(width: 16, height: 16)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 2)

                        Spacer(minLength: 0)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "FF0A3D"), Color(hex: "FF0052")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 30)
                            .overlay(
                                Text("Apply")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
        }
    }
}

private struct NotificationScreenMock: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.black, Color(hex: "242C37"), Color(hex: "1A0F1A")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 8) {
                Text("13:22")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 4)

                Spacer()
            }

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "E5E8EE").opacity(0.76))
                .frame(width: 216, height: 64)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("PILL REMINDER")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color(hex: "6B7383"))
                            Spacer()
                            Text("1m ago")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color(hex: "7A8393"))
                        }
                        Text("Medicine Reminder")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "2D3440"))
                        Text("Time to take: Aspirin")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(hex: "39404D"))
                    }
                    .padding(.horizontal, 12)
                }
                .offset(y: 26)
        }
    }
}

#Preview("Hero Background") {
    HeroBackground(style: .list)
        .frame(height: 320)
}

#Preview("Phone Mock") {
    PhoneMock(style: .list)
        .frame(width: 250, height: 485)
        .padding()
        .background(Color(hex: "F2F3F5"))
}
