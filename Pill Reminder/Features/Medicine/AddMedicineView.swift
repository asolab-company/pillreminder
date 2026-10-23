import SwiftUI
import SwiftData

struct AddMedicineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let defaultDate: Date
    let onSaved: (() -> Void)?

    @State private var step: AddMedicineStep = .form
    @State private var selectedInterval: IntervalOption?

    @State private var medicineName = ""
    @State private var dosage = ""
    @State private var startTimeText: String
    @State private var startDateText: String
    @State private var durationText = "7"
    @State private var errorMessage: String?
    @State private var isSavingMedication = false
    @State private var isDatePickerPresented = false
    @State private var isTimePickerPresented = false
    @State private var pickerWorkingDate: Date

    init(defaultDate: Date = Date(), onSaved: (() -> Void)? = nil) {
        self.defaultDate = defaultDate
        self.onSaved = onSaved

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "dd.MM.yyyy"

        _startTimeText = State(initialValue: timeFormatter.string(from: defaultDate))
        _startDateText = State(initialValue: dateFormatter.string(from: defaultDate))
        _pickerWorkingDate = State(initialValue: defaultDate)
    }

    var body: some View {
        ZStack {
            Color(hex: "F2F2F2").opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                HStack {
                    Text(step == .form ? "Add Medicine" : "Intervals")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(hex: "232833"))

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
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
                .padding(.top, 12)
                .padding(.horizontal, 22)

                if step == .form {
                    formStepView
                } else {
                    intervalStepView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .blur(radius: isPickerPresented ? 2.5 : 0)
            .allowsHitTesting(!isPickerPresented)

            if isPickerPresented {
                Color.black.opacity(0.14)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissPickers()
                    }

                if isDatePickerPresented {
                    MainCalendarPickerOverlay(
                        initialDate: pickerWorkingDate,
                        onClose: {
                            dismissPickers()
                        },
                        onApply: { date in
                            applyPickedDate(date)
                        }
                    )
                    .transition(.opacity)
                } else if isTimePickerPresented {
                    AddMedicineTimePickerOverlay(
                        initialDate: pickerWorkingDate,
                        onClose: {
                            dismissPickers()
                        },
                        onApply: { date in
                            applyPickedTime(date)
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .animation(.easeInOut(duration: 0.2), value: isDatePickerPresented)
        .animation(.easeInOut(duration: 0.2), value: isTimePickerPresented)
        .onChange(of: medicineName) { _, newValue in
            let filtered = filteredMedicineName(newValue)
            if filtered != newValue {
                medicineName = filtered
            }
        }
        .onChange(of: dosage) { _, newValue in
            let filtered = filteredDosage(newValue)
            if filtered != newValue {
                dosage = filtered
            }
        }
        .onChange(of: durationText) { _, newValue in
            let filtered = newValue.filter(\.isNumber)
            if filtered != newValue {
                durationText = filtered
            }
        }
    }

    private var formStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                InputCard(title: "Medicine Name *") {
                    StyledTextField(
                        text: $medicineName,
                        placeholder: "e.g. Aspirin"
                    )
                }

                InputCard(title: "Dosage *") {
                    StyledTextField(
                        text: $dosage,
                        placeholder: "Dosage *"
                    )
                }

                InputCard(title: "Start Time") {
                    StyledPickerField(
                        text: startTimeText,
                        placeholder: "HH:MM",
                        action: presentTimePicker
                    )
                }

                InputCard(title: "Start Date") {
                    StyledPickerField(
                        text: startDateText,
                        placeholder: "DD.MM.YYYY",
                        action: presentDatePicker
                    )
                }

                InputCard(title: "Duration (days)") {
                    VStack(alignment: .leading, spacing: 8) {
                        StyledTextField(
                            text: $durationText,
                            placeholder: "7",
                            keyboardType: .numberPad
                        )

                        Text("End date: \(endDatePreviewText)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(hex: "AAB1BD"))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 2)
            .padding(.bottom, 16)
        }
    }

    private var intervalStepView: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color(hex: "FFFFFF").opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color(hex: "FFFFFF"), lineWidth: 1)
            }
            .overlay {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(IntervalOption.all) { option in
                            Button {
                                selectedInterval = option
                            } label: {
                                HStack {
                                    Text(option.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(
                                            selectedInterval == option
                                            ? Color(hex: "FF0A3D")
                                            : Color(hex: "3F4654")
                                        )
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                            }
                            .buttonStyle(.plain)

                            if option.id != IntervalOption.all.last?.id {
                                Divider()
                                    .overlay(Color(hex: "99A1AF"))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var bottomActionBar: some View {
        VStack(spacing: 6) {
            Button(action: primaryAction) {
                Text("Continue")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FF2450"), Color(hex: "FF002B")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "FF0A3D").opacity(0.25), radius: 8, y: 3)
            }
            .padding(.horizontal, 26)
            .opacity(isContinueEnabled ? 1 : 0.45)
            .disabled(!isContinueEnabled)

            if step == .interval {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        step = .form
                    }
                } label: {
                    Text("Back")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "FF0A3D"))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "FF0A3D"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 26)
                    .frame(height: 40)
            } else {
                Color.clear.frame(height: 40)
            }

        }
        .padding(.top, 8)
        .background(Color(hex: "F2F2F2").opacity(0.7))
    }

    private var endDatePreviewText: String {
        guard let parsed = parseCombinedDate(),
              let duration = Int(durationText.trimmingCharacters(in: .whitespacesAndNewlines)),
              duration > 0,
              let end = Calendar.current.date(byAdding: .day, value: duration - 1, to: parsed)
        else {
            return "--"
        }

        return Self.dateFormatter.string(from: end)
    }

    private func primaryAction() {
        switch step {
        case .form:
            validateAndProceedToIntervals()
        case .interval:
            guard isContinueEnabled else { return }
            saveMedication()
        }
    }

    private var isContinueEnabled: Bool {
        switch step {
        case .form:
            return true
        case .interval:
            return selectedInterval != nil && !isSavingMedication
        }
    }

    private var isPickerPresented: Bool {
        isDatePickerPresented || isTimePickerPresented
    }

    private func presentDatePicker() {
        errorMessage = nil
        pickerWorkingDate = currentCombinedDateOrDefault()
        withAnimation(.easeInOut(duration: 0.2)) {
            isTimePickerPresented = false
            isDatePickerPresented = true
        }
    }

    private func presentTimePicker() {
        errorMessage = nil
        pickerWorkingDate = currentCombinedDateOrDefault()
        withAnimation(.easeInOut(duration: 0.2)) {
            isDatePickerPresented = false
            isTimePickerPresented = true
        }
    }

    private func dismissPickers() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isDatePickerPresented = false
            isTimePickerPresented = false
        }
    }

    private func applyPickedDate(_ date: Date) {
        let calendar = Calendar.current
        let current = currentCombinedDateOrDefault()
        let dateComps = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComps = calendar.dateComponents([.hour, .minute], from: current)

        var merged = DateComponents()
        merged.year = dateComps.year
        merged.month = dateComps.month
        merged.day = dateComps.day
        merged.hour = timeComps.hour
        merged.minute = timeComps.minute

        guard let result = calendar.date(from: merged) else {
            dismissPickers()
            return
        }

        pickerWorkingDate = result
        startDateText = Self.dateFormatter.string(from: result)
        errorMessage = nil
        dismissPickers()
    }

    private func applyPickedTime(_ date: Date) {
        let calendar = Calendar.current
        let current = currentCombinedDateOrDefault()
        let dateComps = calendar.dateComponents([.year, .month, .day], from: current)
        let timeComps = calendar.dateComponents([.hour, .minute], from: date)

        var merged = DateComponents()
        merged.year = dateComps.year
        merged.month = dateComps.month
        merged.day = dateComps.day
        merged.hour = timeComps.hour
        merged.minute = timeComps.minute

        guard let result = calendar.date(from: merged) else {
            dismissPickers()
            return
        }

        pickerWorkingDate = result
        startTimeText = Self.timeFormatter.string(from: result)
        errorMessage = nil
        dismissPickers()
    }

    private func validateAndProceedToIntervals() {
        guard validatedInput() != nil else {
            return
        }

        errorMessage = nil
        selectedInterval = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            step = .interval
        }
    }

    private func saveMedication() {
        guard let selectedInterval else {
            return
        }

        guard let input = validatedInput() else {
            step = .form
            return
        }

        let intervalMinutes = selectedInterval.minutes
        let name = input.name
        let dosage = input.dosage
        let startDate = input.startDate
        let durationDays = input.durationDays

        isSavingMedication = true

        Task {
            _ = await MedicationReminderScheduler.shared.requestAuthorizationIfNeeded()

            await MainActor.run {
                let medication = Medication(
                    name: name,
                    dosage: dosage,
                    startDate: startDate,
                    durationDays: durationDays,
                    intervalMinutes: intervalMinutes
                )

                modelContext.insert(medication)
                try? modelContext.save()
                errorMessage = nil
                onSaved?()
                dismiss()
                isSavingMedication = false
            }

            await refreshReminderScheduleAsync()
        }
    }

    private func validatedInput() -> ValidatedInput? {
        let trimmedName = medicineName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter medicine name"
            return nil
        }

        guard !trimmedDosage.isEmpty else {
            errorMessage = "Please enter dosage"
            return nil
        }

        guard let duration = Int(durationText.trimmingCharacters(in: .whitespacesAndNewlines)), duration > 0 else {
            errorMessage = "Duration should be a positive number"
            return nil
        }

        guard let plannedDateTime = parseCombinedDate() else {
            errorMessage = "Invalid date or time format"
            return nil
        }

        return ValidatedInput(
            name: trimmedName,
            dosage: trimmedDosage,
            startDate: plannedDateTime,
            durationDays: duration
        )
    }

    private func parseCombinedDate() -> Date? {
        let trimmedDate = startDateText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTime = startTimeText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let datePart = Self.dateFormatter.date(from: trimmedDate)
                ?? Self.legacyDateFormatter.date(from: trimmedDate),
              let timePart = Self.timeFormatter.date(from: trimmedTime)
        else {
            return nil
        }

        let calendar = Calendar.current
        let dateComps = calendar.dateComponents([.year, .month, .day], from: datePart)
        let timeComps = calendar.dateComponents([.hour, .minute], from: timePart)

        var combined = DateComponents()
        combined.year = dateComps.year
        combined.month = dateComps.month
        combined.day = dateComps.day
        combined.hour = timeComps.hour
        combined.minute = timeComps.minute

        return calendar.date(from: combined)
    }

    private func currentCombinedDateOrDefault() -> Date {
        parseCombinedDate() ?? defaultDate
    }

    private func refreshReminderScheduleAsync() async {
        let payloads: [MedicationReminderPayload] = await MainActor.run {
            let descriptor = FetchDescriptor<Medication>()
            let medications = (try? modelContext.fetch(descriptor)) ?? []
            return medications.map(\.reminderPayload)
        }

        await MedicationReminderScheduler.shared.syncSchedules(for: payloads)
    }

    private func filteredMedicineName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_"))

        return String(value.unicodeScalars.filter { allowed.contains($0) })
    }

    private func filteredDosage(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: ".,/%+-"))

        return String(value.unicodeScalars.filter { allowed.contains($0) })
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private static let legacyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd:MM:yyyy"
        return formatter
    }()
}

private struct InputCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(hex: "FFFFFF")).opacity(0.7)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(hex: "FFFFFF"), lineWidth: 1)
            }
            .overlay {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "222222"))

                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .frame(minHeight: 106)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

private struct StyledTextField: View {
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Color(hex: "99A1AF")))
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Color(hex: "343A46"))
            .keyboardType(keyboardType)
            .padding(.horizontal, 14)
            .frame(height: 49)
            .background(Color(hex: "FFFFFF"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hex: "99A1AF").opacity(0.5), lineWidth: 0.75)
            }
    }
}

private struct StyledPickerField: View {
    let text: String
    let placeholder: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(displayText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(hex: "99A1AF")
                            : Color(hex: "343A46")
                    )
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 49)
            .background(Color(hex: "FFFFFF"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(hex: "99A1AF").opacity(0.5), lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
    }

    private var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? placeholder : trimmed
    }
}

private enum AddMedicineStep {
    case form
    case interval
}

private struct ValidatedInput {
    let name: String
    let dosage: String
    let startDate: Date
    let durationDays: Int
}

private struct IntervalOption: Identifiable, Equatable {
    let id: Int
    let title: String
    let minutes: Int

    static let all: [IntervalOption] = [
        IntervalOption(id: 15, title: "Every 15 min", minutes: 15),
        IntervalOption(id: 30, title: "Every 30 min", minutes: 30),
        IntervalOption(id: 60, title: "Every 1 hour", minutes: 60),
        IntervalOption(id: 120, title: "Every 2 hours", minutes: 120),
        IntervalOption(id: 180, title: "Every 3 hours", minutes: 180),
        IntervalOption(id: 240, title: "Every 4 hours", minutes: 240),
        IntervalOption(id: 360, title: "Every 6 hours", minutes: 360),
        IntervalOption(id: 480, title: "Every 8 hours", minutes: 480),
        IntervalOption(id: 720, title: "Every 12 hours", minutes: 720),
        IntervalOption(id: 1440, title: "Every 24 hours", minutes: 1440),
        IntervalOption(id: 2880, title: "Every 2 days", minutes: 2880)
    ]

    static let defaultOption = IntervalOption(id: 720, title: "Every 12 hours", minutes: 720)
}
