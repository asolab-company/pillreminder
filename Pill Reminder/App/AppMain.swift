import SwiftUI
import SwiftData

@main
struct Pill_ReminderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var storeKitManager = StoreKitManager()

    init() {
        Self.prepareApplicationSupportDirectory()
    }

    var body: some Scene {
        WindowGroup {
            GeometryReader { proxy in
                ContentView()
                    .environmentObject(storeKitManager)
                    .environment(\.deviceSize, DeviceSize(size: CGSize(
                        width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                        height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                    )))
            }
        }
        .modelContainer(for: Medication.self)
    }

    private static func prepareApplicationSupportDirectory() {
        guard let url = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return
        }

        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}
