// MARK: - PrayerTimerMonitor.swift
// Monitors prayer times and shows an alert after a configurable delay.

import SwiftUI
import Combine

class PrayerTimerMonitor {
    @AppStorage("isPrayerTimerEnabled") private var isEnabled: Bool = false
    @AppStorage("prayerTimerDuration") private var duration: Int = 5
    
    private var timer: Timer?
    private var lastPrayerTimes: [String: Date]?
    private var lastNextPrayerName: String?

    // R5-1: Track previous values for change detection
    // (@AppStorage reads from UserDefaults, so comparing it WITH UserDefaults is always equal)
    private var trackedEnabled: Bool
    private var trackedDuration: Int

    init() {
        // Snapshot initial values
        self.trackedEnabled = UserDefaults.standard.bool(forKey: "isPrayerTimerEnabled")
        self.trackedDuration = UserDefaults.standard.integer(forKey: "prayerTimerDuration")
        
        NotificationCenter.default.addObserver(self, selector: #selector(handlePrayerTimeUpdate), name: .prayerTimesUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc private func handlePrayerTimeUpdate(notification: Notification) {
        // Store the latest prayer data for later use
        if let info = notification.userInfo {
            lastPrayerTimes = info["prayerTimes"] as? [String: Date]
            lastNextPrayerName = info["nextPrayerName"] as? String
        }
        rescheduleTimer()
    }
    
    @objc private func settingsChanged() {
        // R5-1: Compare against tracked snapshots, not live UserDefaults
        let currentEnabled = UserDefaults.standard.bool(forKey: "isPrayerTimerEnabled")
        let currentDuration = UserDefaults.standard.integer(forKey: "prayerTimerDuration")
        if currentEnabled != trackedEnabled || currentDuration != trackedDuration {
            trackedEnabled = currentEnabled
            trackedDuration = currentDuration
            rescheduleTimer()
        }
    }
    
    private func rescheduleTimer() {
        timer?.invalidate()

        guard isEnabled,
              let prayerTimes = lastPrayerTimes else {
            return
        }
        
        // Find the prayer time that most recently passed
        guard let prayerThatJustPassed = prayerTimes.values
                .filter({ $0 < Date() })
                .max() else { return }

        let triggerTime = prayerThatJustPassed.addingTimeInterval(TimeInterval(duration * 60))
        
        let timeUntilTrigger = triggerTime.timeIntervalSinceNow
        guard timeUntilTrigger > 0 else { return }

        timer = Timer.scheduledTimer(withTimeInterval: timeUntilTrigger, repeats: false) { _ in
            // C-004: Don't show alert if Adhan is currently playing
            guard !AdhanAlertService.shared.isPlaying else { return }
            AlertWindowManager.shared.showAlert(autoDismissAfter: 10 * 60)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
