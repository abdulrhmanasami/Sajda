// MARK: - NotificationManager.swift
// Schedules and manages local notifications for prayer times.

import Foundation
import UserNotifications

struct NotificationManager {
    
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("[Sajda] Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    static func scheduleNotifications(for prayerTimes: [String: Date], prayerOrder: [String], adhanSound: AdhanSound, customSoundPath: String) {
        cancelNotifications()
        
        for prayerName in prayerOrder {
            guard let prayerTime = prayerTimes[prayerName] else { continue }
            
            if prayerTime > Date() {
                let content = UNMutableNotificationContent()
                let localizedPrayerName = NSLocalizedString(prayerName, comment: "")
                content.title = localizedPrayerName
                content.body = String(format: NSLocalizedString("notification_prayer_body", comment: ""), localizedPrayerName)
                
                switch adhanSound {
                case .none:
                    content.sound = nil
                case .defaultBeep:
                    content.sound = UNNotificationSound.default
                case .custom:
                    // R2-7: Use default sound as notification fallback.
                    // Custom Adhan sound is played separately via NSSound/AdhanAlertService.
                    content.sound = UNNotificationSound.default
                }

                let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: prayerTime)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
                let request = UNNotificationRequest(identifier: prayerName, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request)
            }
        }
    }
    
    static func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
