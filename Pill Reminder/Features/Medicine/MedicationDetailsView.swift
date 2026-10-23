import SwiftData
import SwiftUI

struct MedicationDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let medication: Medication

    @State private var isDeleteAlertPresented = false
    @State private var isEditPresented = false

    var body: some View {
        ZStack {
            Color(hex: "F2F3F5").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                content
            }
        }
        .fullScreenCover(isPresented: $isEditPresented) {
            EditMedicationView(medication: medication)
        }
        .alert("Delete medicine?", isPresented: $isDeleteAlertPresented) {
            Button("Delete", role: .destructive) {
                deleteMedication()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var topBar: some View {
        ZStack {
            Text(medication.name)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(hex: "232833"))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 112)

            HStack {
                Button {
                    dismiss()
                } label: {
                    circleIconButtonBackground(icon: "chevron.left", color: Color(hex: "9CA5B3"))
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        isDeleteAlertPresented = true
                    } label: {
                        circleIconButtonBackground(icon: "trash", color: Color(hex: "FF0A3D"))
                    }
                    .buttonStyle(.plain)

                    Button {
                        isEditPresented = true
                    } label: {
                        circleIconButtonBackground(icon: "pencil", color: Color(hex: "8C94A3"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                medicationHeaderCard

                if status == .completed {
                    Button {
                        startTakingAgain()
                    } label: {
                        Text("Start Taking Again")
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
                    .buttonStyle(.plain)

                }

                detailsSectionCard(
                    icon: "clock",
                    iconColor: Color(hex: "FF3B30"),
                    title: "Schedule"
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Frequency")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(hex: "A1A9B7"))
                        Text(frequencyText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(hex: "2D3440"))
                    }
                }

                detailsSectionCard(
                    icon: "calendar",
                    iconColor: Color(hex: "FF2D55"),
                    title: "Duration"
                ) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Date")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(hex: "A1A9B7"))
                            Text(Self.longDateFormatter.string(from: medication.startDate))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(hex: "2D3440"))
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 2) {
                            Text("End Date")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(hex: "A1A9B7"))
                            Text(Self.longDateFormatter.string(from: medication.endDate))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: "2D3440"))
                        }
                    }
                }

                detailsSectionCard(
                    icon: "clock.badge.checkmark",
                    iconColor: Color(hex: "F4B400"),
                    title: "Upcoming reminders"
                ) {
                    if upcomingReminderDates.isEmpty {
                        Text("No Upcoming reminders")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(hex: "AAB1BD"))
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(upcomingReminderDates, id: \.self) { date in
                                Text(Self.dateTimeFormatter.string(from: date))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color(hex: "2D3440"))
                            }
                        }
                    }
                }

                detailsSectionCard(
                    icon: "clock.arrow.circlepath",
                    iconColor: Color(hex: "2F7BFF"),
                    title: "History"
                ) {
                    if historyReminderDates.isEmpty {
                        Text("No history yet")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(hex: "AAB1BD"))
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(historyReminderDates, id: \.self) { date in
                                Text(Self.dateTimeFormatter.string(from: date))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color(hex: "2D3440"))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }

    private var medicationHeaderCard: some View {
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
                        Text(medication.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "2D3440"))

                        Text(medication.dosage)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(hex: "99A1AF"))

                        Text(intervalDescription)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(hex: "99A1AF"))
                    }

                    Spacer()

                    Text(status.title)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(status.textColor)
                        .padding(.horizontal, 16)
                        .frame(height: 24)
                        .background(status.backgroundColor)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 90)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    @ViewBuilder
    private func detailsSectionCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "2D3440"))
            }

            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "FFFFFF").opacity(0.7))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "FFFFFF"), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .frame(minHeight: 108, alignment: .top)
    }

    private func circleIconButtonBackground(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "F1F3F6"))
            Circle()
                .stroke(Color(hex: "FFD5DF"), lineWidth: 1)
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 40, height: 40)
    }

    private var status: MedicationDetailsStatus {
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

    private var intervalDescription: String {
        Self.intervalDescription(for: medication.intervalMinutes)
    }

    private var frequencyText: String {
        let safeInterval = max(medication.intervalMinutes, 1)
        let times = max(1, (24 * 60) / safeInterval)
        if times == 1 {
            return "1 time per day"
        }
        return "\(times) times per day"
    }

    private var upcomingReminderDates: [Date] {
        occurrences(
            from: max(Date(), firstReminderDate),
            to: medication.endDate,
            limit: 2
        )
    }

    private var historyReminderDates: [Date] {
        let now = min(Date(), medication.endDate)
        guard now >= firstReminderDate else { return [] }

        let interval = TimeInterval(max(medication.intervalMinutes, 1) * 60)
        let elapsed = now.timeIntervalSince(firstReminderDate)
        let lastStep = Int(floor(elapsed / interval))
        let firstStep = max(lastStep - 3, 0)

        return stride(from: lastStep, through: firstStep, by: -1).map { step in
            firstReminderDate.addingTimeInterval(Double(step) * interval)
        }
    }

    private var firstReminderDate: Date {
        medication.startDate.addingTimeInterval(TimeInterval(max(medication.intervalMinutes, 1) * 60))
    }

    private func occurrences(from start: Date, to end: Date, limit: Int) -> [Date] {
        guard start <= end else { return [] }

        let interval = TimeInterval(max(medication.intervalMinutes, 1) * 60)
        var result: [Date] = []
        var current = alignedOccurrenceStart(for: start)

        while current <= end && result.count < limit {
            result.append(current)
            current = current.addingTimeInterval(interval)
        }

        return result
    }

    private func alignedOccurrenceStart(for date: Date) -> Date {
        let interval = TimeInterval(max(medication.intervalMinutes, 1) * 60)
        if date <= firstReminderDate {
            return firstReminderDate
        }

        let elapsed = date.timeIntervalSince(firstReminderDate)
        let steps = Int(ceil(elapsed / interval))
        return firstReminderDate.addingTimeInterval(Double(steps) * interval)
    }

    private func startTakingAgain() {
        medication.startDate = Date()
        medication.endDate = Calendar.current.date(
            byAdding: .day,
            value: max(medication.durationDays - 1, 0),
            to: medication.startDate
        ) ?? medication.startDate

        try? modelContext.save()
        syncReminderSchedule()
    }

    private func deleteMedication() {
        DoseActionStore.removeEntries(forMedicationCreatedAt: medication.createdAt)
        modelContext.delete(medication)
        try? modelContext.save()
        syncReminderSchedule()
        dismiss()
    }

    private func syncReminderSchedule() {
        Task {
            let payloads: [MedicationReminderPayload] = await MainActor.run {
                let descriptor = FetchDescriptor<Medication>()
                let medications = (try? modelContext.fetch(descriptor)) ?? []
                return medications.map(\.reminderPayload)
            }
            await MedicationReminderScheduler.shared.syncSchedules(for: payloads)
        }
    }

    private static func intervalDescription(for minutes: Int) -> String {
        if minutes < 60 {
            return "Every \(minutes) min"
        }
        if minutes % (24 * 60) == 0 {
            let days = minutes / (24 * 60)
            return days == 1 ? "Every 1 day" : "Every \(days) days"
        }
        if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "Every 1 hour" : "Every \(hours) hours"
        }
        return "Every \(minutes) min"
    }

    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d, yyyy, HH:mm"
        return formatter
    }()
}

private struct EditMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let medication: Medication

    @State private var name: String
    @State private var dosage: String
    @State private var startDateText: String
    @State private var startTimeText: String
    @State private var durationText: String
    @State private var selectedIntervalMinutes: Int
    @State private var errorText: String?
    @State private var isDatePickerPresented = false
    @State private var isTimePickerPresented = false
    @State private var pickerWorkingDate: Date

    init(medication: Medication) {
        self.medication = medication
        _name = State(initialValue: medication.name)
        _dosage = State(initialValue: medication.dosage)
        _startDateText = State(initialValue: Self.dateFormatter.string(from: medication.startDate))
        _startTimeText = State(initialValue: Self.timeFormatter.string(from: medication.startDate))
        _durationText = State(initialValue: String(medication.durationDays))
        _selectedIntervalMinutes = State(initialValue: medication.intervalMinutes)
        _pickerWorkingDate = State(initialValue: medication.startDate)
    }

    var body: some View {
        ZStack {
            Color(hex: "F2F2F2").opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                HStack {
                    Text("Edit Medicine")
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
                .padding(.horizontal, 22)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        editCard(title: "Medicine Name *") {
                            styledTextField(
                                text: $name,
                                placeholder: "e.g. Aspirin"
                            )
                        }

                        editCard(title: "Dosage *") {
                            styledTextField(
                                text: $dosage,
                                placeholder: "Dosage *"
                            )
                        }

                        editCard(title: "Start Time") {
                            styledPickerField(
                                text: startTimeText,
                                placeholder: "HH:MM",
                                action: presentTimePicker
                            )
                        }

                        editCard(title: "Start Date") {
                            styledPickerField(
                                text: startDateText,
                                placeholder: "DD.MM.YYYY",
                                action: presentDatePicker
                            )
                        }

                        editCard(title: "Duration (days)") {
                            VStack(alignment: .leading, spacing: 8) {
                                styledTextField(
                                    text: $durationText,
                                    placeholder: "7",
                                    keyboardType: .numberPad
                                )

                                Text("End date: \(endDatePreviewText)")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color(hex: "AAB1BD"))
                            }
                        }

                        editCard(title: "Interval") {
                            Menu {
                                ForEach(Self.intervalOptions, id: \.minutes) { option in
                                    Button(option.title) {
                                        selectedIntervalMinutes = option.minutes
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedIntervalTitle)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundStyle(Color(hex: "343A46"))
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color(hex: "99A1AF"))
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
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
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
            VStack(spacing: 6) {
                Button {
                    save()
                } label: {
                    Text("Save")
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
                .buttonStyle(.plain)
                .padding(.horizontal, 26)

                if let errorText {
                    Text(errorText)
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
        .animation(.easeInOut(duration: 0.2), value: isDatePickerPresented)
        .animation(.easeInOut(duration: 0.2), value: isTimePickerPresented)
        .onChange(of: name) { _, value in
            let filtered = filteredMedicineName(value)
            if filtered != value {
                name = filtered
            }
        }
        .onChange(of: dosage) { _, value in
            let filtered = filteredDosage(value)
            if filtered != value {
                dosage = filtered
            }
        }
        .onChange(of: durationText) { _, value in
            let filtered = value.filter(\.isNumber)
            if filtered != value {
                durationText = filtered
            }
        }
    }

    private var isPickerPresented: Bool {
        isDatePickerPresented || isTimePickerPresented
    }

    private var endDatePreviewText: String {
        guard
            let startDate = parseCombinedDate(),
            let duration = Int(durationText.trimmingCharacters(in: .whitespacesAndNewlines)),
            duration > 0,
            let endDate = Calendar.current.date(byAdding: .day, value: duration - 1, to: startDate)
        else {
            return "--"
        }

        return Self.dateFormatter.string(from: endDate)
    }

    private func presentDatePicker() {
        errorText = nil
        pickerWorkingDate = currentCombinedDateOrDefault()
        withAnimation(.easeInOut(duration: 0.2)) {
            isTimePickerPresented = false
            isDatePickerPresented = true
        }
    }

    private func presentTimePicker() {
        errorText = nil
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
        errorText = nil
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
        errorText = nil
        dismissPickers()
    }

    private func parseCombinedDate() -> Date? {
        let trimmedDate = startDateText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTime = startTimeText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let datePart = Self.dateFormatter.date(from: trimmedDate),
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
        parseCombinedDate() ?? medication.startDate
    }

    @ViewBuilder
    private func editCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(hex: "FFFFFF").opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(hex: "FFFFFF"), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "222222"))
                    content()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .frame(minHeight: 106)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private func styledTextField(
        text: Binding<String>,
        placeholder: String,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        TextField(
            "",
            text: text,
            prompt: Text(placeholder).foregroundStyle(Color(hex: "99A1AF"))
        )
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

    private func styledPickerField(
        text: String,
        placeholder: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(displayText(text: text, placeholder: placeholder))
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

    private func displayText(text: String, placeholder: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? placeholder : trimmed
    }

    private var selectedIntervalTitle: String {
        Self.intervalOptions.first(where: { $0.minutes == selectedIntervalMinutes })?.title
            ?? "Every \(selectedIntervalMinutes) min"
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let startDate = parseCombinedDate() else {
            errorText = "Invalid date or time format"
            return
        }

        guard !trimmedName.isEmpty else {
            errorText = "Please enter medicine name"
            return
        }
        guard !trimmedDosage.isEmpty else {
            errorText = "Please enter dosage"
            return
        }
        guard let duration = Int(durationText), duration > 0 else {
            errorText = "Duration should be a positive number"
            return
        }

        errorText = nil
        medication.name = trimmedName
        medication.dosage = trimmedDosage
        medication.startDate = startDate
        medication.durationDays = duration
        medication.intervalMinutes = selectedIntervalMinutes
        medication.endDate = Calendar.current.date(
            byAdding: .day,
            value: max(duration - 1, 0),
            to: startDate
        ) ?? startDate

        try? modelContext.save()
        syncReminderSchedule()
        dismiss()
    }

    private func syncReminderSchedule() {
        Task {
            let payloads: [MedicationReminderPayload] = await MainActor.run {
                let descriptor = FetchDescriptor<Medication>()
                let medications = (try? modelContext.fetch(descriptor)) ?? []
                return medications.map(\.reminderPayload)
            }
            await MedicationReminderScheduler.shared.syncSchedules(for: payloads)
        }
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

    private struct IntervalOption {
        let title: String
        let minutes: Int
    }

    private static let intervalOptions: [IntervalOption] = [
        IntervalOption(title: "Every 15 min", minutes: 15),
        IntervalOption(title: "Every 30 min", minutes: 30),
        IntervalOption(title: "Every 1 hour", minutes: 60),
        IntervalOption(title: "Every 2 hours", minutes: 120),
        IntervalOption(title: "Every 3 hours", minutes: 180),
        IntervalOption(title: "Every 4 hours", minutes: 240),
        IntervalOption(title: "Every 6 hours", minutes: 360),
        IntervalOption(title: "Every 8 hours", minutes: 480),
        IntervalOption(title: "Every 12 hours", minutes: 720),
        IntervalOption(title: "Every 24 hours", minutes: 1440),
        IntervalOption(title: "Every 2 days", minutes: 2880)
    ]

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
}

private enum MedicationDetailsStatus {
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
            return Color(hex: "FFBB00")
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
