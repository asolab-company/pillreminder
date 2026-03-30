import SwiftUI

struct AddMedicineTimePickerOverlay: View {
    private let onClose: () -> Void
    private let onApply: (Date) -> Void

    @State private var selectedTime: Date

    init(
        initialDate: Date,
        onClose: @escaping () -> Void,
        onApply: @escaping (Date) -> Void
    ) {
        self.onClose = onClose
        self.onApply = onApply
        _selectedTime = State(initialValue: initialDate)
    }

    var body: some View {
        VStack {
            timeCard
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timeCard: some View {
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

            Text("Select Time")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color(hex: "2D3440"))
                .padding(.top, 8)

            DatePicker(
                "",
                selection: $selectedTime,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipped()
            .padding(.top, 10)

            Button {
                onApply(selectedTime)
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
            .padding(.top, 16)
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
}

#Preview("Add Medicine Time Overlay") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        AddMedicineTimePickerOverlay(
            initialDate: Date(),
            onClose: {},
            onApply: { _ in }
        )
    }
}
