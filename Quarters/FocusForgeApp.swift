import SwiftUI
import SwiftData
import UserNotifications

@main
struct FocusForgeApp: App {

    private let notificationDelegate = NotificationDelegate()

    init() {
        Fonts.registerBundled()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
            #if os(macOS)
                .frame(width: 500, height: 660)
            #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        #endif
        .modelContainer(for: [Session.self, FocusTask.self, LedgerEntry.self, Reward.self, DailyLog.self])
    }
}
