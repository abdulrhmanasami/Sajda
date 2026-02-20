// MARK: - PrayerTimeViewModel.swift
// Thin coordinator that wires LocationService, PrayerCalculationService, and MenuBarService.
// Views continue to use @EnvironmentObject(viewModel) — no view changes needed.

import Foundation
import Combine
import CoreLocation
import SwiftUI
import AppKit
import NavigationStack

class PrayerTimeViewModel: ObservableObject {

    // MARK: - Services

    let locationService = LocationService()
    let calculationService = PrayerCalculationService()
    let menuBarService = MenuBarService()

    // MARK: - Forwarded Published State (so Views keep working via viewModel.property)

    @Published var menuTitle: NSAttributedString = NSAttributedString(string: "Sajda Pro")
    @Published var todayTimes: [String: Date] = [:]
    @Published var nextPrayerName: String = ""
    @Published var countdown: String = "--:--"
    @Published var locationStatusText: String = "Preparing prayer schedule..."
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationSearchQuery: String = "" { didSet { locationService.locationSearchQuery = locationSearchQuery } }
    @Published var locationSearchResults: [LocationSearchResult] = []
    @Published var isLocationSearching: Bool = false
    @Published var locationInfoText: String = ""
    @Published var isPrayerImminent: Bool = false
    @Published var isRequestingLocation: Bool = false

    // MARK: - Settings (remain on ViewModel for View compatibility)

    @AppStorage("animationType") var animationType: AnimationType = .fade
    @AppStorage("useMinimalMenuBarText") var useMinimalMenuBarText: Bool = false { didSet { syncMenuBarConfig(); updateMenuTitle() } }
    @AppStorage("showSunnahPrayers") var showSunnahPrayers: Bool = false { didSet { calculationService.showSunnahPrayers = showSunnahPrayers; calculationService.updatePrayerTimes() } }
    @AppStorage("useAccentColor") var useAccentColor: Bool = true
    @AppStorage("isNotificationsEnabled") var isNotificationsEnabled: Bool = true { didSet { calculationService.isNotificationsEnabled = isNotificationsEnabled } }
    @AppStorage("useCompactLayout") var useCompactLayout: Bool = false
    @AppStorage("use24HourFormat") var use24HourFormat: Bool = false { didSet { syncMenuBarConfig(); updateMenuTitle() } }
    @AppStorage("useHanafiMadhhab") var useHanafiMadhhab: Bool = false { didSet { calculationService.useHanafiMadhhab = useHanafiMadhhab; calculationService.updatePrayerTimes() } }
    @AppStorage("isUsingManualLocation") var isUsingManualLocation: Bool = false
    @AppStorage("fajrCorrection") var fajrCorrection: Double = 0 { didSet { calculationService.fajrCorrection = fajrCorrection; calculationService.updatePrayerTimes() } }
    @AppStorage("dhuhrCorrection") var dhuhrCorrection: Double = 0 { didSet { calculationService.dhuhrCorrection = dhuhrCorrection; calculationService.updatePrayerTimes() } }
    @AppStorage("asrCorrection") var asrCorrection: Double = 0 { didSet { calculationService.asrCorrection = asrCorrection; calculationService.updatePrayerTimes() } }
    @AppStorage("maghribCorrection") var maghribCorrection: Double = 0 { didSet { calculationService.maghribCorrection = maghribCorrection; calculationService.updatePrayerTimes() } }
    @AppStorage("ishaCorrection") var ishaCorrection: Double = 0 { didSet { calculationService.ishaCorrection = ishaCorrection; calculationService.updatePrayerTimes() } }
    @AppStorage("adhanSound") var adhanSound: AdhanSound = .defaultBeep { didSet { calculationService.adhanSound = adhanSound } }
    @AppStorage("customAdhanSoundPath") var customAdhanSoundPath: String = "" { didSet { calculationService.customAdhanSoundPath = customAdhanSoundPath } }
    @AppStorage("isPersistentAdhanEnabled") var isPersistentAdhanEnabled: Bool = false { didSet { calculationService.isPersistentAdhanEnabled = isPersistentAdhanEnabled } }
    @AppStorage("persistentAdhanVolume") var persistentAdhanVolume: Double = 0.7 { didSet { calculationService.persistentAdhanVolume = Float(persistentAdhanVolume) } }
    @AppStorage("adhanOutputDeviceUID") var adhanOutputDeviceUID: String = "" { didSet { calculationService.adhanOutputDeviceUID = adhanOutputDeviceUID } }

    @Published var menuBarTextMode: MenuBarTextMode {
        didSet {
            UserDefaults.standard.set(menuBarTextMode.rawValue, forKey: "menuBarTextMode")
            if menuBarTextMode == .hidden { useMinimalMenuBarText = false }
            syncMenuBarConfig()
            updateMenuTitle()
        }
    }

    @Published var method: SajdaCalculationMethod {
        didSet {
            UserDefaults.standard.set(method.name, forKey: "calculationMethodName")
            calculationService.method = method
            calculationService.updatePrayerTimes()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        let savedMethodName = UserDefaults.standard.string(forKey: "calculationMethodName") ?? "Muslim World League"
        self.method = SajdaCalculationMethod.allCases.first { $0.name == savedMethodName } ?? .allCases[0]
        let savedTextMode = UserDefaults.standard.string(forKey: "menuBarTextMode")
        self.menuBarTextMode = MenuBarTextMode(rawValue: savedTextMode ?? "") ?? .countdown

        // Sync initial settings to services
        calculationService.method = self.method
        calculationService.languageIdentifier = "en" // Default; AppDelegate will push real value
        
        // M-007: Explicit initial sync — @AppStorage didSet doesn't fire for initial values
        calculationService.adhanSound = adhanSound
        calculationService.customAdhanSoundPath = customAdhanSoundPath
        calculationService.showSunnahPrayers = showSunnahPrayers
        calculationService.isNotificationsEnabled = isNotificationsEnabled
        calculationService.isPersistentAdhanEnabled = isPersistentAdhanEnabled
        calculationService.persistentAdhanVolume = Float(persistentAdhanVolume)
        calculationService.adhanOutputDeviceUID = adhanOutputDeviceUID
        calculationService.fajrCorrection = fajrCorrection
        calculationService.dhuhrCorrection = dhuhrCorrection
        calculationService.asrCorrection = asrCorrection
        calculationService.maghribCorrection = maghribCorrection
        calculationService.ishaCorrection = ishaCorrection

        syncMenuBarConfig()
        setupBindings()

        // Wire location → calculation
        locationService.onCoordinatesUpdated = { [weak self] coordinates, timeZone in
            self?.calculationService.updateCoordinates(coordinates, timeZone: timeZone)
            self?.menuBarService.setTimeZone(timeZone)
        }

        // Wire calculation → menu bar
        calculationService.onMenuTitleNeedsUpdate = { [weak self] in
            self?.syncMenuBarData()
            self?.menuBarService.updateTitle()
        }

        calculationService.startTimer()
    }

    // MARK: - Navigation Animations

    func forwardAnimation() -> NavigationAnimation? {
        switch animationType {
        case .none: return nil
        case .fade: return .sajdaCrossfade
        case .slide: return .push
        }
    }

    func backwardAnimation() -> NavigationAnimation? {
        switch animationType {
        case .none: return nil
        case .fade: return .sajdaCrossfade
        case .slide: return .pop
        }
    }

    // MARK: - Forwarded API (Views call these)

    func startLocationProcess() { locationService.startLocationProcess() }
    func setManualLocation(city: String, coordinates: CLLocationCoordinate2D) { locationService.setManualLocation(city: city, coordinates: coordinates) }
    func switchToAutomaticLocation() { locationService.switchToAutomaticLocation() }
    func requestLocationPermission() { locationService.requestLocationPermission() }
    func openLocationSettings() { locationService.openLocationSettings() }
    func selectCustomAdhanSound() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.audio]
        if openPanel.runModal() == .OK, let url = openPanel.url {
            // RCA-2: Store the raw file path (no URL encoding)
            self.customAdhanSoundPath = url.path
            
            // RCA-3: Save security-scoped bookmark for sandbox persistence across launches
            do {
                let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmark, forKey: "customAdhanSoundBookmark")
            } catch {
                print("[Sajda] Failed to create security-scoped bookmark: \(error)")
            }
        }
    }
    func updatePrayerTimes() { calculationService.updatePrayerTimes() }
    func updateMenuTitle() { syncMenuBarData(); menuBarService.updateTitle() }
    var isPrayerDataAvailable: Bool { calculationService.isPrayerDataAvailable }
    var dateFormatter: DateFormatter { menuBarService.dateFormatter }

    /// Called by AppDelegate when language changes (single source of truth).
    func updateLanguage(_ language: String) {
        calculationService.languageIdentifier = language
        menuBarService.languageIdentifier = language
        updateMenuTitle()
    }

    // MARK: - Private — Combine Bindings

    private func setupBindings() {
        // Forward LocationService → ViewModel
        locationService.$locationStatusText.assign(to: &$locationStatusText)
        locationService.$authorizationStatus.assign(to: &$authorizationStatus)
        locationService.$locationSearchResults.assign(to: &$locationSearchResults)
        locationService.$isLocationSearching.assign(to: &$isLocationSearching)
        locationService.$locationInfoText.assign(to: &$locationInfoText)
        locationService.$isRequestingLocation.assign(to: &$isRequestingLocation)

        // Forward PrayerCalculationService → ViewModel
        calculationService.$todayTimes.assign(to: &$todayTimes)
        calculationService.$nextPrayerName.assign(to: &$nextPrayerName)
        calculationService.$countdown.assign(to: &$countdown)
        calculationService.$isPrayerImminent.assign(to: &$isPrayerImminent)

        // Forward MenuBarService → ViewModel
        menuBarService.$menuTitle.assign(to: &$menuTitle)

        // Sync search query from ViewModel → LocationService
        $locationSearchQuery
            .removeDuplicates()
            .sink { [weak self] query in
                self?.locationService.locationSearchQuery = query
            }
            .store(in: &cancellables)
    }

    private func syncMenuBarConfig() {
        menuBarService.menuBarTextMode = menuBarTextMode
        menuBarService.useMinimalMenuBarText = useMinimalMenuBarText
        menuBarService.use24HourFormat = use24HourFormat
    }

    private func syncMenuBarData() {
        menuBarService.nextPrayerName = calculationService.nextPrayerName
        menuBarService.todayTimes = calculationService.todayTimes
        menuBarService.tomorrowFajrTime = calculationService.tomorrowFajrTime
        menuBarService.countdown = calculationService.countdown
        menuBarService.isPrayerImminent = calculationService.isPrayerImminent
        menuBarService.isPrayerDataAvailable = calculationService.isPrayerDataAvailable
    }
}
