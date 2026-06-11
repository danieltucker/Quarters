import SwiftUI
import SwiftData
import UserNotifications

@main
struct FocusForgeApp: App {

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 500, height: 660)
        }
        .windowResizability(.contentSize)
        .modelContainer(for: [Session.self, FocusTask.self, LedgerEntry.self, Reward.self])
    }
}
