// MARK: - PrayerTimelineEntry.swift
// Timeline entry model for WidgetKit.

import WidgetKit

struct PrayerTimelineEntry: TimelineEntry {
    let date: Date
    let prayerTimes: [PrayerItem]
    let nextPrayerName: String
    let nextPrayerTime: Date?
    let locationName: String
    let isPlaceholder: Bool
    
    struct PrayerItem: Identifiable {
        let id: String
        let name: String
        let time: Date
        var isPassed: Bool { time < Date() }
        var isNext: Bool { false } // Set by the view
    }
    
    /// Placeholder entry for widget preview.
    static var placeholder: PrayerTimelineEntry {
        PrayerTimelineEntry(
            date: Date(),
            prayerTimes: [
                PrayerItem(id: "Fajr", name: "Fajr", time: Calendar.current.date(bySettingHour: 5, minute: 30, second: 0, of: Date())!),
                PrayerItem(id: "Dhuhr", name: "Dhuhr", time: Calendar.current.date(bySettingHour: 12, minute: 15, second: 0, of: Date())!),
                PrayerItem(id: "Asr", name: "Asr", time: Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!),
                PrayerItem(id: "Maghrib", name: "Maghrib", time: Calendar.current.date(bySettingHour: 18, minute: 5, second: 0, of: Date())!),
                PrayerItem(id: "Isha", name: "Isha", time: Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: Date())!),
            ],
            nextPrayerName: "Dhuhr",
            nextPrayerTime: Calendar.current.date(bySettingHour: 12, minute: 15, second: 0, of: Date()),
            locationName: "Mecca",
            isPlaceholder: true
        )
    }
}
