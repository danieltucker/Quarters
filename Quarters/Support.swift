import UserNotifications
import CoreText
#if os(macOS)
import AppKit
#else
import AudioToolbox
import UIKit
#endif

enum Haptics {
    /// Light selection tick for the quarter dial. No-op on macOS.
    static func tick() {
        #if os(iOS)
        let g = UISelectionFeedbackGenerator()
        g.selectionChanged()
        #endif
    }
}

enum Fonts {
    /// macOS loads bundled fonts via the ATSApplicationFontsPath Info.plist
    /// key; iOS has no equivalent that works with a generated Info.plist,
    /// so register the bundled .ttf files with CoreText at launch.
    static func registerBundled() {
        #if os(iOS)
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
                 + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "fonts") ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        #endif
    }
}

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
                #if os(macOS)
                if let s = NSSound(named: "Glass") {
                    s.play()
                } else {
                    NSSound.beep()
                }
                #else
                AudioServicesPlaySystemSound(1013)   // glass-like chime
                #endif
            }
        }
    }

    private static var lastClink = Date.distantPast

    /// Coin clink for flight arrivals. Throttled so big pours don't
    /// machine-gun the speaker.
    static func clink() {
        let now = Date()
        guard now.timeIntervalSince(lastClink) > 0.06 else { return }
        lastClink = now
        #if os(macOS)
        // NSSound(named:) returns a shared instance that won't restart
        // while playing, so play a copy for overlap.
        guard let s = NSSound(named: "Tink")?.copy() as? NSSound else { return }
        s.volume = Float.random(in: 0.35...0.6)
        s.play()
        #else
        AudioServicesPlaySystemSound(1057)   // Tink
        #endif
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

    /// Once the user is looking at the checkoff screen, the session-end
    /// banner in Notification Center is stale — clear it.
    static func clearDelivered() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

/// Without a delegate, notifications are silently suppressed while the app
/// is frontmost — so a session ending with the window hidden or minimized
/// showed nothing. Present the banner regardless; the in-app chime already
/// covers sound, so .sound is deliberately omitted to avoid doubling up.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler:
                                            @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}
