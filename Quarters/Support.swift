import AppKit
import UserNotifications

extension Notification.Name {
    /// Posted by CheckoffView when coins are collected; ContentView listens
    /// and plays the coin-flight animation up to the balance chip.
    static let qCoinsCollected = Notification.Name("qCoinsCollected")
    /// Posted by RewardsView on redeem; ContentView shows the celebration
    /// popup and flies coins from the chip into it.
    static let qCoinsSpent = Notification.Name("qCoinsSpent")
}

enum Sounds {
    /// Triple chime when a session completes.
    static func tripleBeep() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35) {
                if let s = NSSound(named: "Glass") {
                    s.play()
                } else {
                    NSSound.beep()
                }
            }
        }
    }
}

enum Notifications {
    private static let sessionEndId = "focusforge.session.end"

    /// Fires even if the app is in the background or the window is closed.
    static func scheduleSessionEnd(at date: Date, blockCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Time's up"
        content.body = "Your \(blockCount * 15)-minute session is done. Check off what you accomplished."
        content.sound = .default

        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: sessionEndId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelSessionEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [sessionEndId])
    }
}
