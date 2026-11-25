import SwiftUI

struct PulseDefaultCameraSetting: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PulseCameraChoice.preferenceKey) private var preferredID: String?
    @State private var choices: [PulseCameraChoice] = []
    @State private var isPresented = false

    private var selection: PulseCameraChoice? { choices.first { $0.id == preferredID } }

    var body: some View {
        Button { isPresented = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill").foregroundStyle(PulseStyle.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Default camera").font(.headline)
                    Text(selection?.name ?? "Automatic").font(.subheadline).foregroundStyle(PulseStyle.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(PulseStyle.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(17).background(.white, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.defaultCamera")
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            let available = await Task.detached(priority: .userInitiated) { PulseCameraInventory().choices }.value
            if !Task.isCancelled { choices = available }
        }
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                List {
                    Section {
                        option("Automatic", id: nil)
                        ForEach(choices) { choice in option(choice.name, id: choice.id) }
                    } footer: {
                        Text("Automatic uses the main rear camera when available. Choose the lens that’s most comfortable to cover with your index finger near the flash.")
                    }
                }
                .navigationTitle("Default camera").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Close") { isPresented = false } }
                }
            }
            .tint(PulseStyle.accent)
            .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
    }

    private func option(_ name: String, id: String?) -> some View {
        Button {
            preferredID = id
            isPresented = false
        } label: {
            HStack {
                Text(name).foregroundStyle(PulseStyle.primaryText)
                Spacer()
                if selection?.id == id {
                    Image(systemName: "checkmark").foregroundStyle(PulseStyle.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(selection?.id == id ? .isSelected : [])
    }
}
