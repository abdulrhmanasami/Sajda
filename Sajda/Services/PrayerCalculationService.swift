// MARK: - PrayerCalculationService.swift
// Handles Adhan prayer time calculations, time corrections, countdown, and notifications.

import Foundation
import Combine
import Adhan
import CoreLocation
import SwiftUI

class PrayerCalculationService: ObservableObject {

    // MARK: - Published State

    @Published var todayTimes: [String: Date] = [:]
    @Published var nextPrayerName: String = ""
    @Published var countdown: String = "--:--"
    @Published var isPrayerImminent: Bool = false

    // MARK: - Settings (set by ViewModel — single source of truth)

    var showSunnahPrayers: Bool = false
    var useHanafiMadhhab: Bool = false
    var isNotificationsEnabled: Bool = true
    var adhanSound: AdhanSound = .defaultBeep
    var customAdhanSoundPath: String = ""
    var fajrCorrection: Double = 0
    var dhuhrCorrection: Double = 0
    var asrCorrection: Double = 0
    var maghribCorrection: Double = 0
    var ishaCorrection: Double = 0

    // MARK: - Internal State

    private(set) var tomorrowFajrTime: Date?
    private var timer: Timer?
    private var lastCalculationDate: Date?
    private var currentCoordinates: CLLocationCoordinate2D?
    private var locationTimeZone: TimeZone = .current
    private var adhanPlayer: NSSound?

    /// The active calculation method.
    var method: SajdaCalculationMethod = .allCases[0]

    /// Called when the menu title should be refreshed.
    var onMenuTitleNeedsUpdate: (() -> Void)?

    /// Language identifier for localization.
    var languageIdentifier: String = "en"

    // MARK: - Public API

    func updateCoordinates(_ coordinates: CLLocationCoordinate2D, timeZone: TimeZone) {
        self.currentCoordinates = coordinates
        self.locationTimeZone = timeZone
        updatePrayerTimes()
    }

    func updatePrayerTimes() {
        guard let coord = currentCoordinates else { return }

        lastCalculationDate = Date()

        var locationCalendar = Calendar(identifier: .gregorian)
        locationCalendar.timeZone = self.locationTimeZone
        let todayInLocation = locationCalendar.dateComponents([.year, .month, .day], from: Date())
        let tomorrowInLocation = locationCalendar.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowDC = locationCalendar.dateComponents([.year, .month, .day], from: tomorrowInLocation)

        var params = method.params
        params.madhab = self.useHanafiMadhhab ? .hanafi : .shafi

        guard let prayersToday = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: todayInLocation, calculationParameters: params),
              let prayersTomorrow = PrayerTimes(coordinates: Coordinates(latitude: coord.latitude, longitude: coord.longitude), date: tomorrowDC, calculationParameters: params) else { return }

        let correctedFajr = prayersToday.fajr.addingTimeInterval(fajrCorrection * 60)
        let correctedDhuhr = prayersToday.dhuhr.addingTimeInterval(dhuhrCorrection * 60)
        let correctedAsr = prayersToday.asr.addingTimeInterval(asrCorrection * 60)
        let correctedMaghrib = prayersToday.maghrib.addingTimeInterval(maghribCorrection * 60)
        let correctedIsha = prayersToday.isha.addingTimeInterval(ishaCorrection * 60)

        var allPrayerTimes: [(name: String, time: Date)] = [
            ("Fajr", correctedFajr), ("Dhuhr", correctedDhuhr), ("Asr", correctedAsr),
            ("Maghrib", correctedMaghrib), ("Isha", correctedIsha)
        ]

        if showSunnahPrayers {
            let correctedFajrTomorrow = prayersTomorrow.fajr.addingTimeInterval(fajrCorrection * 60)
            let nightDuration = correctedFajrTomorrow.timeIntervalSince(correctedIsha)
            let lastThirdOfNightStart = correctedIsha.addingTimeInterval(nightDuration * (2.0 / 3.0))
            allPrayerTimes.append(("Tahajud", lastThirdOfNightStart))

            let dhuhaTime = prayersToday.sunrise.addingTimeInterval(20 * 60)
            allPrayerTimes.append(("Dhuha", dhuhaTime))
        }

        let correctedFajrTomorrow = prayersTomorrow.fajr.addingTimeInterval(fajrCorrection * 60)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.todayTimes = Dictionary(uniqueKeysWithValues: allPrayerTimes.map { ($0.name, $0.time) })
            self.tomorrowFajrTime = correctedFajrTomorrow
            self.updateNextPrayer()
            self.updateNotifications()

            // Notify PrayerTimerMonitor
            NotificationCenter.default.post(
                name: .prayerTimesUpdated,
                object: nil,
                userInfo: [
                    "prayerTimes": self.todayTimes,
                    "nextPrayerName": self.nextPrayerName
                ]
            )
        }
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let lastDate = self.lastCalculationDate,
               !Calendar.current.isDate(lastDate, inSameDayAs: Date()) {
                self.updatePrayerTimes()
            } else {
                self.updateCountdown()
            }
        }
    }

    var isPrayerDataAvailable: Bool { !todayTimes.isEmpty }

    // MARK: - Private

    private func updateNextPrayer() {
        let now = Date()
        var potentialPrayers = todayTimes.map { (key: $0.key, value: $0.value) }
        if let fajrTomorrow = tomorrowFajrTime {
            potentialPrayers.append((key: "Fajr", value: fajrTomorrow))
        }
        let allSortedPrayers = potentialPrayers.sorted { $0.value < $1.value }
        let listToSearch: [(key: String, value: Date)]
        if showSunnahPrayers {
            listToSearch = allSortedPrayers
        } else {
            listToSearch = allSortedPrayers.filter { $0.key != "Tahajud" && $0.key != "Dhuha" }
        }

        if let nextPrayer = listToSearch.first(where: { $0.value > now }) {
            self.nextPrayerName = nextPrayer.key
        } else if let firstPrayerOfNextCycle = listToSearch.first {
            self.nextPrayerName = firstPrayerOfNextCycle.key
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.updatePrayerTimes()
            }
        }
        updateCountdown()
    }

    private func updateCountdown() {
        var nextPrayerDate: Date?
        if nextPrayerName == "Fajr" && todayTimes["Fajr"] ?? Date() < Date() {
            nextPrayerDate = tomorrowFajrTime
        } else {
            nextPrayerDate = todayTimes[nextPrayerName]
        }

        guard let nextDate = nextPrayerDate else {
            countdown = "--:--"
            onMenuTitleNeedsUpdate?()
            return
        }

        let diff = Int(nextDate.timeIntervalSince(Date()))
        isPrayerImminent = (diff <= 600 && diff > 0)

        if diff > 0 {
            let h = diff / 3600
            let m = (diff % 3600) / 60
            let numberFormatter = NumberFormatter()
            numberFormatter.locale = Locale(identifier: languageIdentifier)
            let formattedM = numberFormatter.string(from: NSNumber(value: m + 1)) ?? "\(m + 1)"
            if h > 0 {
                let formattedH = numberFormatter.string(from: NSNumber(value: h)) ?? "\(h)"
                countdown = "\(formattedH)h \(formattedM)m"
            } else {
                countdown = "\(formattedM)m"
            }
        } else {
            countdown = "Now"
            if adhanSound == .custom,
               let soundPath = customAdhanSoundPath.removingPercentEncoding,
               let soundURL = URL(string: soundPath),
               FileManager.default.fileExists(atPath: soundURL.path) {
                adhanPlayer = NSSound(contentsOf: soundURL, byReference: true)
                adhanPlayer?.play()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.updateNextPrayer() }
        }
        onMenuTitleNeedsUpdate?()
    }

    private func updateNotifications() {
        guard isNotificationsEnabled, !todayTimes.isEmpty else {
            NotificationManager.cancelNotifications()
            return
        }
        NotificationManager.requestPermission()
        var prayersToNotify = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        if showSunnahPrayers {
            if todayTimes.keys.contains("Tahajud") { prayersToNotify.append("Tahajud") }
            if todayTimes.keys.contains("Dhuha") { prayersToNotify.append("Dhuha") }
        }
        NotificationManager.scheduleNotifications(
            for: todayTimes,
            prayerOrder: prayersToNotify,
            adhanSound: self.adhanSound,
            customSoundPath: self.customAdhanSoundPath
        )
    }
}
