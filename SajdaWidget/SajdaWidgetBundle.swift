// MARK: - SajdaWidgetBundle.swift
// Widget extension entry point with Small, Medium, and Large prayer time widgets.

import WidgetKit
import SwiftUI

@main
struct SajdaWidgetBundle: WidgetBundle {
    var body: some Widget {
        SajdaPrayerWidget()
    }
}

// MARK: - Prayer Widget Definition

struct SajdaPrayerWidget: Widget {
    let kind: String = "SajdaPrayerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            SajdaWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Prayer Times")
        .description("View today's prayer times at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Adaptive Entry View

struct SajdaWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PrayerTimelineEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallPrayerWidgetView(entry: entry)
        case .systemMedium:
            MediumPrayerWidgetView(entry: entry)
        case .systemLarge:
            LargePrayerWidgetView(entry: entry)
        default:
            SmallPrayerWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallPrayerWidgetView: View {
    let entry: PrayerTimelineEntry
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Sajda")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            Spacer()
            
            if !entry.isPlaceholder {
                Text(entry.nextPrayerName)
                    .font(.title2.weight(.bold))
                
                if let nextTime = entry.nextPrayerTime {
                    Text(timeFormatter.string(from: nextTime))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    Text(nextTime, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } else {
                Text("Dhuhr")
                    .font(.title2.weight(.bold))
                    .redacted(reason: .placeholder)
                Text("12:15 PM")
                    .font(.title3)
                    .redacted(reason: .placeholder)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget

struct MediumPrayerWidgetView: View {
    let entry: PrayerTimelineEntry
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Sajda")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.locationName)
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.5))
            }
            
            Divider()
            
            // Prayer List
            ForEach(entry.prayerTimes) { prayer in
                let isNext = prayer.name == entry.nextPrayerName
                
                HStack {
                    Circle()
                        .fill(isNext ? Color.green : (prayer.isPassed ? Color.secondary.opacity(0.3) : Color.clear))
                        .frame(width: 6, height: 6)
                    
                    Text(prayer.name)
                        .font(.callout)
                        .fontWeight(isNext ? .bold : .regular)
                        .foregroundStyle(prayer.isPassed && !isNext ? .secondary : .primary)
                    
                    Spacer()
                    
                    if isNext {
                        Text(prayer.time, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    
                    Text(timeFormatter.string(from: prayer.time))
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(isNext ? .bold : .regular)
                        .foregroundStyle(prayer.isPassed && !isNext ? .secondary : .primary)
                }
                .padding(.vertical, 1)
            }
        }
    }
}

// MARK: - Large Widget

struct LargePrayerWidgetView: View {
    let entry: PrayerTimelineEntry
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .font(.body)
                        Text("Sajda")
                            .font(.headline)
                    }
                    Text(dateFormatter.string(from: Date()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.locationName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // Next Prayer Highlight
            if let nextTime = entry.nextPrayerTime {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Next Prayer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(entry.nextPrayerName)
                            .font(.title2.weight(.bold))
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(timeFormatter.string(from: nextTime))
                            .font(.title3.weight(.semibold))
                        Text(nextTime, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.green.opacity(0.1)))
            }
            
            Divider()
            
            // Full Prayer List
            ForEach(entry.prayerTimes) { prayer in
                let isNext = prayer.name == entry.nextPrayerName
                
                HStack {
                    Image(systemName: prayer.isPassed ? "checkmark.circle.fill" : (isNext ? "arrow.right.circle.fill" : "circle"))
                        .font(.caption)
                        .foregroundStyle(isNext ? .green : (prayer.isPassed ? .secondary : .gray.opacity(0.5)))
                    
                    Text(prayer.name)
                        .font(.callout)
                        .fontWeight(isNext ? .bold : .regular)
                        .foregroundStyle(prayer.isPassed && !isNext ? .secondary : .primary)
                    
                    Spacer()
                    
                    Text(timeFormatter.string(from: prayer.time))
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(isNext ? .bold : .regular)
                        .foregroundStyle(prayer.isPassed && !isNext ? .secondary : .primary)
                }
                .padding(.vertical, 2)
            }
            
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    SajdaPrayerWidget()
} timeline: {
    PrayerTimelineEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    SajdaPrayerWidget()
} timeline: {
    PrayerTimelineEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    SajdaPrayerWidget()
} timeline: {
    PrayerTimelineEntry.placeholder
}
