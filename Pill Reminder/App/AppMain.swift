
import SwiftUI
import SwiftData

@main
struct Pill_ReminderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var storeKitManager = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storeKitManager)
        }
        .modelContainer(for: Medication.self)
    }
}

#Preview("App Root") {
    ContentView()
        .environmentObject(StoreKitManager())
        .modelContainer(for: Medication.self, inMemory: true)
}
