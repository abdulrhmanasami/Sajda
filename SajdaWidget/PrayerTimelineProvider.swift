// MARK: - PrayerTimelineProvider.swift
// Generates timeline entries for the prayer times widget.

import WidgetKit

struct PrayerTimelineProvider: TimelineProvider {
    
    typealias Entry = PrayerTimelineEntry
    
    func placeholder(in context: Context) -> PrayerTimelineEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PrayerTimelineEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        completion(buildCurrentEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimelineEntry>) -> Void) {
        guard let sharedData = SharedDefaults.read() else {
            // No data yet — show placeholder and retry in 15 minutes
            let entry = PrayerTimelineEntry.placeholder
            let retryDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(retryDate)))
            return
        }
        
        let items = sharedData.prayerTimes.map { prayer in
            PrayerTimelineEntry.PrayerItem(
                id: prayer.name,
                name: prayer.name,
                time: prayer.time
            )
        }
        
        // Generate an entry at each prayer transition point
        var entries: [PrayerTimelineEntry] = []
        let now = Date()
        
        // Current entry
        entries.append(PrayerTimelineEntry(
            date: now,
            prayerTimes: items,
            nextPrayerName: sharedData.nextPrayerName,
            nextPrayerTime: items.first(where: { $0.name == sharedData.nextPrayerName })?.time,
            locationName: sharedData.locationName,
            isPlaceholder: false
        ))
        
        // Future entries at each prayer time (to update "next prayer" indicator)
        for prayer in sharedData.prayerTimes where prayer.time > now {
            let nextIndex = sharedData.prayerTimes.firstIndex(where: { $0.name == prayer.name }).map { $0 + 1 }
            let nextPrayer = nextIndex.flatMap { idx in
                idx < sharedData.prayerTimes.count ? sharedData.prayerTimes[idx] : nil
            }
            
            entries.append(PrayerTimelineEntry(
                date: prayer.time,
                prayerTimes: items,
                nextPrayerName: nextPrayer?.name ?? "Fajr",
                nextPrayerTime: nextPrayer?.time,
                locationName: sharedData.locationName,
                isPlaceholder: false
            ))
        }
        
        // Refresh at midnight for next day's times
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
        let timeline = Timeline(entries: entries, policy: .after(tomorrow))
        completion(timeline)
    }
    
    // MARK: - Private
    
    private func buildCurrentEntry() -> PrayerTimelineEntry {
        guard let sharedData = SharedDefaults.read() else {
            return .placeholder
        }
        
        let items = sharedData.prayerTimes.map { prayer in
            PrayerTimelineEntry.PrayerItem(
                id: prayer.name,
                name: prayer.name,
                time: prayer.time
            )
        }
        
        return PrayerTimelineEntry(
            date: Date(),
            prayerTimes: items,
            nextPrayerName: sharedData.nextPrayerName,
            nextPrayerTime: items.first(where: { $0.name == sharedData.nextPrayerName })?.time,
            locationName: sharedData.locationName,
            isPlaceholder: false
        )
    }
}
