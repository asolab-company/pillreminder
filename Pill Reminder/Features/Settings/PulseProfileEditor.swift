import SwiftUI

struct PulseProfileCard: View {
    let profile: PulseProfile
    let edit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.text.rectangle").foregroundStyle(PulseStyle.accent)
                Text("Pulse profile").font(.headline)
                Spacer()
                Button("Edit", action: edit)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(PulseStyle.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Edit pulse profile").accessibilityIdentifier("profile.edit")
            }
            if profile.hasDetails {
                Divider()
                if let sex = profile.sex { LabeledContent("Sex", value: sex.rawValue) }
                ForEach(PulseProfile.Field.allCases, id: \.self) { field in
                    if let value = profile[keyPath: field.key] {
                        LabeledContent(field.rawValue, value: "\(value) \(field.unit)")
                    }
                }
                if let bmi = profile.bmi {
                    LabeledContent("BMI", value: bmi.formatted(.number.precision(.fractionLength(1))))
                }
            } else {
                Text("Add the details you’d like to keep in your profile.")
                    .foregroundStyle(PulseStyle.secondary)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 18).padding(.top, 5).padding(.bottom, 17)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct PulseProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: PulseProfile.Field?
    @State private var sex: PulseProfile.Sex?
    @State private var values: [PulseProfile.Field: String]
    private let original: PulseProfile
    private let fields: [PulseProfile.Field]

    init(profile: PulseProfile) {
        original = profile
        fields = profile.age == nil ? [.height, .weight] : [.height, .weight, .age]
        _sex = State(initialValue: profile.sex)
        _values = State(initialValue: Dictionary(uniqueKeysWithValues: fields.map { field in
            (field, profile[keyPath: field.key].map(String.init) ?? "")
        }))
    }

    private var editedProfile: PulseProfile? {
        var result = original
        result.sex = sex
        for field in fields {
            let text = values[field, default: ""]
            guard field.accepts(text) else { return nil }
            result[keyPath: field.key] = Int(text)
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Sex", selection: $sex) {
                        Text("Not set").tag(nil as PulseProfile.Sex?)
                        ForEach(PulseProfile.Sex.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(Optional(option))
                        }
                    }
                    ForEach(fields, id: \.self) { field in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(field.rawValue)
                                Spacer(minLength: 8)
                                TextField("Not set", text: Binding(
                                    get: { values[field, default: ""] },
                                    set: { values[field] = $0 }
                                ))
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad).focused($focusedField, equals: field)
                                    .accessibilityLabel(field.rawValue)
                                    .accessibilityIdentifier("profile.\(field.rawValue.lowercased())")
                                Text(field.unit).foregroundStyle(PulseStyle.secondary)
                                if focusedField == field, !values[field, default: ""].isEmpty {
                                    Button {
                                        values[field] = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                            .frame(minWidth: 36, minHeight: 44)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Clear \(field.rawValue.lowercased())")
                                    .accessibilityIdentifier("profile.clear.\(field.rawValue.lowercased())")
                                }
                            }
                            if !field.accepts(values[field, default: ""]) {
                                Text("Enter a whole number from \(field.range.lowerBound) to \(field.range.upperBound) \(field.unit).")
                                    .font(.footnote).foregroundStyle(PulseStyle.accent)
                            }
                        }
                    }
                } footer: {
                    Text("Leave any field blank to remove it from your profile.")
                }
                if let bmi = editedProfile?.bmi {
                    LabeledContent("BMI", value: bmi.formatted(.number.precision(.fractionLength(1))))
                }
            }
            .navigationTitle("Edit pulse profile").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let profile = editedProfile else { return }
                        profile.save()
                        dismiss()
                    }
                    .disabled(editedProfile == nil)
                    .accessibilityIdentifier("profile.save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
        .tint(PulseStyle.accent)
        .presentationDragIndicator(.visible)
    }
}
