// MARK: - MenuBarService.swift
// Handles formatting the menu bar title based on prayer data and display preferences.

import Foundation
import AppKit
import SwiftUI

class MenuBarService: ObservableObject {

    // MARK: - Published State

    @Published var menuTitle: NSAttributedString = NSAttributedString(string: "Sajda Pro")

    // MARK: - Configuration

    var menuBarTextMode: MenuBarTextMode = .countdown
    var useMinimalMenuBarText: Bool = false
    var use24HourFormat: Bool = false
    var languageIdentifier: String = "en"

    // MARK: - Data Sources (set by ViewModel)

    var nextPrayerName: String = ""
    var todayTimes: [String: Date] = [:]
    var tomorrowFajrTime: Date?
    var countdown: String = "--:--"
    var isPrayerImminent: Bool = false
    var isPrayerDataAvailable: Bool = false

    // MARK: - Cached Formatter

    private var _dateFormatter: DateFormatter?
    private var _lastFormatConfig: String = ""
    /// R6-1: Stored timezone for manual location support — survives formatter recreation.
    private var _storedTimeZone: TimeZone = .current

    var dateFormatter: DateFormatter {
        let configKey = "\(use24HourFormat)-\(useMinimalMenuBarText)-\(languageIdentifier)-\(_storedTimeZone.identifier)"
        if let cached = _dateFormatter, _lastFormatConfig == configKey {
            return cached
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageIdentifier)
        // R6-1: Apply stored timezone (could be manual location's, not .current)
        formatter.timeZone = _storedTimeZone
        if useMinimalMenuBarText {
            formatter.dateFormat = use24HourFormat ? "H.mm" : "h.mm"
        } else {
            formatter.timeStyle = .short
        }
        _dateFormatter = formatter
        _lastFormatConfig = configKey
        return formatter
    }

    // MARK: - Public API

    func updateTitle() {
        guard isPrayerDataAvailable else {
            self.menuTitle = NSAttributedString(string: "Sajda Pro")
            return
        }

        var textToShow = ""
        let localizedPrayerName = NSLocalizedString(nextPrayerName, comment: "")

        switch menuBarTextMode {
        case .hidden:
            textToShow = ""

        case .countdown:
            if useMinimalMenuBarText {
                textToShow = "\(localizedPrayerName) -\(countdown)"
            } else {
                textToShow = String(format: NSLocalizedString("prayer_in_countdown", comment: ""), localizedPrayerName, countdown)
            }

        case .exactTime:
            var nextPrayerDate: Date?
            if nextPrayerName == "Fajr" && todayTimes["Fajr"] ?? Date() < Date() {
                nextPrayerDate = tomorrowFajrTime
            } else {
                nextPrayerDate = todayTimes[nextPrayerName]
            }

            guard let nextDate = nextPrayerDate else {
                textToShow = "Sajda Pro"
                break
            }

            if useMinimalMenuBarText {
                textToShow = "\(localizedPrayerName) \(dateFormatter.string(from: nextDate))"
            } else {
                textToShow = String(format: NSLocalizedString("prayer_at_time", comment: ""), localizedPrayerName, dateFormatter.string(from: nextDate))
            }
        }

        let attributes: [NSAttributedString.Key: Any] = isPrayerImminent ? [.foregroundColor: NSColor.systemRed] : [:]
        self.menuTitle = NSAttributedString(string: textToShow, attributes: attributes)
    }

    /// Updates the formatter's timezone (for manual location support).
    func setTimeZone(_ tz: TimeZone) {
        // R6-1: Store timezone so newly created formatters also get it
        _storedTimeZone = tz
        _dateFormatter?.timeZone = tz
        _lastFormatConfig = "" // Force re-creation on next access
    }
}
