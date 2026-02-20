// MARK: - SharedPrayerData.swift
// Data model shared between the main app and the widget extension via App Groups.

import Foundation

/// The App Group identifier for sharing data between the main app and widgets.
let appGroupID = "group.com.sajda.shared"

/// Prayer data written by the main app, read by the widget.
struct SharedPrayerData: Codable {
    let prayerTimes: [PrayerEntry]
    let nextPrayerName: String
    let locationName: String
    let calculationMethod: String
    let calculatedAt: Date
    let languageIdentifier: String
    
    struct PrayerEntry: Codable {
        let name: String
        let time: Date
    }
}

/// Convenience wrapper around the shared App Group UserDefaults.
enum SharedDefaults {
    static var suite: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
    
    static let prayerDataKey = "shared_prayer_data"
    
    /// Write prayer data from the main app.
    static func write(_ data: SharedPrayerData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        suite.set(encoded, forKey: prayerDataKey)
    }
    
    /// Read prayer data from the widget.
    static func read() -> SharedPrayerData? {
        guard let data = suite.data(forKey: prayerDataKey) else { return nil }
        return try? JSONDecoder().decode(SharedPrayerData.self, from: data)
    }
}
