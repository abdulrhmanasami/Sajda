// MARK: - LocationService.swift
// Manages CLLocationManager, geocoding, Nominatim search, and coordinate parsing.

import Foundation
import Combine
import CoreLocation
import SwiftUI

@propertyWrapper
struct FlexibleDouble: Codable, Equatable, Hashable {
    var wrappedValue: Double
    init(wrappedValue: Double) { self.wrappedValue = wrappedValue }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            wrappedValue = doubleValue
        } else if let stringValue = try? container.decode(String.self), let doubleValue = Double(stringValue) {
            wrappedValue = doubleValue
        } else {
            throw DecodingError.typeMismatch(Double.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Double or String representing Double"))
        }
    }
}

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published State

    @Published var locationSearchQuery: String = ""
    @Published var locationSearchResults: [LocationSearchResult] = []
    @Published var isLocationSearching: Bool = false
    @Published var locationStatusText: String = "Preparing prayer schedule..."
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var locationInfoText: String = ""
    @Published var isRequestingLocation: Bool = false

    /// R2-2: Read from UserDefaults so it stays in sync with ViewModel's @AppStorage
    var isUsingManualLocation: Bool {
        get { UserDefaults.standard.bool(forKey: "isUsingManualLocation") }
        set { UserDefaults.standard.set(newValue, forKey: "isUsingManualLocation") }
    }

    // MARK: - Callbacks

    /// Called when coordinates change and prayer times should be recalculated.
    var onCoordinatesUpdated: ((_ coordinates: CLLocationCoordinate2D, _ timeZone: TimeZone) -> Void)?

    // MARK: - Internal State

    private(set) var currentCoordinates: CLLocationCoordinate2D?
    private(set) var locationTimeZone: TimeZone = .current

    private var automaticLocationCache: (name: String, coordinates: CLLocationCoordinate2D)?
    private let locMgr = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    private var locationDisplayTimer: Timer?

    /// R2-3: Cached DateFormatter to avoid re-creating every second
    private lazy var locationTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .medium
        return df
    }()

    // MARK: - Nominatim Models

    private struct NominatimResult: Codable, Hashable {
        @FlexibleDouble var lat: Double; @FlexibleDouble var lon: Double
        let display_name: String; let address: NominatimAddress
    }

    private struct NominatimAddress: Codable, Hashable {
        let city: String?, town: String?, village: String?, state: String?, county: String?, country: String?
    }

    // MARK: - Init

    override init() {
        self.authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        locMgr.delegate = self
        setupSearchPublisher()
    }

    // MARK: - Public API

    func startLocationProcess() {
        if isUsingManualLocation, let manualData = loadManualLocation() {
            currentCoordinates = manualData.coordinates
            locationStatusText = manualData.name
            let location = CLLocation(latitude: manualData.coordinates.latitude, longitude: manualData.coordinates.longitude)
            self.locationTimeZone = TimeZoneLocate.timeZoneWithLocation(location)
            self.authorizationStatus = .authorized
            DispatchQueue.main.async {
                self.notifyCoordinatesUpdated()
                self.startLocationDisplayTimer()
            }
        } else {
            self.locationTimeZone = .current
            handleAuthorizationStatus(status: locMgr.authorizationStatus)
        }
    }

    func setManualLocation(city: String, coordinates: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        self.locationTimeZone = TimeZoneLocate.timeZoneWithLocation(location)

        // R2-4: Save immediately with the provided name, then update asynchronously if geocoded
        isUsingManualLocation = true
        currentCoordinates = coordinates
        authorizationStatus = .authorized
        locationSearchQuery = ""
        locationSearchResults = []

        if city == "Custom Coordinate" {
            // Set temporary display while geocoding
            self.locationStatusText = String(format: "Coord: %.2f, %.2f", coordinates.latitude, coordinates.longitude)
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, _) in
                guard let self = self else { return }
                let resolvedName = placemarks?.first?.locality ?? String(format: "Coord: %.2f, %.2f", coordinates.latitude, coordinates.longitude)
                DispatchQueue.main.async {
                    self.locationStatusText = resolvedName
                    let manualData: [String: Any] = ["name": resolvedName, "latitude": coordinates.latitude, "longitude": coordinates.longitude]
                    UserDefaults.standard.set(manualData, forKey: "manualLocationData")
                }
            }
        } else {
            self.locationStatusText = city
            let manualData: [String: Any] = ["name": city, "latitude": coordinates.latitude, "longitude": coordinates.longitude]
            UserDefaults.standard.set(manualData, forKey: "manualLocationData")
        }

        notifyCoordinatesUpdated()
        startLocationDisplayTimer()
    }

    func switchToAutomaticLocation() {
        isUsingManualLocation = false
        UserDefaults.standard.removeObject(forKey: "manualLocationData")
        stopLocationDisplayTimer()
        if let cache = automaticLocationCache {
            currentCoordinates = cache.coordinates
            locationStatusText = cache.name
            notifyCoordinatesUpdated()
        } else {
            handleAuthorizationStatus(status: locMgr.authorizationStatus)
        }
    }

    func requestLocationPermission() {
        if authorizationStatus == .notDetermined {
            isRequestingLocation = true
            DispatchQueue.main.async { self.locMgr.requestWhenInUseAuthorization() }
        }
    }

    func openLocationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else { return }
        NSWorkspace.shared.open(url)
    }

    func parseCoordinates(from string: String) -> LocationSearchResult? {
        let cleaned = string.replacingOccurrences(of: " ", with: "")
        let components = cleaned.split(separator: ",").compactMap { Double($0) }
        guard components.count == 2,
              let lat = components.first, let lon = components.last,
              (lat >= -90 && lat <= 90) && (lon >= -180 && lon <= 180) else { return nil }
        return LocationSearchResult(
            name: "Custom Coordinate",
            country: String(format: "%.4f, %.4f", lat, lon),
            coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon)
        )
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let location = locs.last else { return }
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, _) in
            DispatchQueue.main.async {
                guard let self = self, let locality = placemarks?.first?.locality else {
                    self?.isRequestingLocation = false
                    return
                }
                self.automaticLocationCache = (name: locality, coordinates: location.coordinate)
                if !self.isUsingManualLocation {
                    self.currentCoordinates = location.coordinate
                    self.locationTimeZone = TimeZoneLocate.timeZoneWithLocation(location)
                    self.locationStatusText = locality
                    self.notifyCoordinatesUpdated()
                }
                if self.isRequestingLocation { self.isRequestingLocation = false }
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if !isUsingManualLocation { handleAuthorizationStatus(status: manager.authorizationStatus) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.isRequestingLocation = false
        self.locationStatusText = "Unable to determine location."
    }

    // MARK: - Private

    private func notifyCoordinatesUpdated() {
        guard let coords = currentCoordinates else { return }
        onCoordinatesUpdated?(coords, locationTimeZone)
    }

    private func handleAuthorizationStatus(status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        switch status {
        case .authorized:
            if automaticLocationCache == nil { locationStatusText = "Fetching Location..." }
            locMgr.requestLocation()
        case .denied, .restricted:
            locationStatusText = "Location access denied."
            isRequestingLocation = false
            // R2-5: Do NOT send empty (0,0) coordinates — let the app stay without prayer data
            // rather than calculate for Gulf of Guinea, Africa
        case .notDetermined:
            isRequestingLocation = false
            locationStatusText = "Location access needed"
        @unknown default:
            isRequestingLocation = false
        }
    }

    private func loadManualLocation() -> (name: String, coordinates: CLLocationCoordinate2D)? {
        guard let data = UserDefaults.standard.dictionary(forKey: "manualLocationData"),
              let name = data["name"] as? String,
              let lat = data["latitude"] as? CLLocationDegrees,
              let lon = data["longitude"] as? CLLocationDegrees else { return nil }
        return (name, CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }

    private func setupSearchPublisher() {
        $locationSearchQuery
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .handleEvents(receiveOutput: { [weak self] query in
                let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
                self?.isLocationSearching = !trimmedQuery.isEmpty
                if trimmedQuery.isEmpty { self?.locationSearchResults = [] }
            })
            .flatMap { [weak self] query -> AnyPublisher<[LocationSearchResult], Never> in
                guard let self = self else { return Just([]).eraseToAnyPublisher() }
                let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
                guard !trimmedQuery.isEmpty else { return Just([]).eraseToAnyPublisher() }

                if let coordResult = self.parseCoordinates(from: trimmedQuery) {
                    return Just([coordResult]).eraseToAnyPublisher()
                }

                var components = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
                components.queryItems = [
                    URLQueryItem(name: "q", value: trimmedQuery),
                    URLQueryItem(name: "format", value: "json"),
                    URLQueryItem(name: "addressdetails", value: "1"),
                    URLQueryItem(name: "accept-language", value: "en"),
                    URLQueryItem(name: "limit", value: "20")
                ]
                guard let url = components.url else { return Just([]).eraseToAnyPublisher() }
                var request = URLRequest(url: url)
                request.setValue("Sajda Pro Prayer Times App/1.0", forHTTPHeaderField: "User-Agent")

                return URLSession.shared.dataTaskPublisher(for: request)
                    .map(\.data)
                    .decode(type: [NominatimResult].self, decoder: JSONDecoder())
                    .catch { error -> Just<[NominatimResult]> in
                        // R2-8: Log search errors for diagnostics
                        print("[Sajda] Nominatim search failed: \(error.localizedDescription)")
                        return Just([])
                    }
                    .map { results -> [LocationSearchResult] in
                        let mappedResults = results.compactMap { result -> LocationSearchResult? in
                            let name = result.address.city ?? result.address.town ?? result.address.village ?? result.address.county ?? result.address.state ?? ""
                            let country = result.address.country ?? ""
                            guard !country.isEmpty else { return nil }
                            let finalName = name.isEmpty ? result.display_name.components(separatedBy: ",")[0] : name
                            return LocationSearchResult(name: finalName, country: country, coordinates: CLLocationCoordinate2D(latitude: result.lat, longitude: result.lon))
                        }
                        return Array(Set(mappedResults)).sorted { $0.name < $1.name }
                    }
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                self?.isLocationSearching = false
                self?.locationSearchResults = results
            }
            .store(in: &cancellables)
    }

    private func startLocationDisplayTimer() {
        stopLocationDisplayTimer()
        locationDisplayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.locationTimeFormatter.timeZone = self.locationTimeZone
            let tzName = self.locationTimeZone.identifier
            let currentTime = self.locationTimeFormatter.string(from: Date())
            self.locationInfoText = "Timezone: \(tzName) | Current Time: \(currentTime)"
        }
    }

    private func stopLocationDisplayTimer() {
        locationDisplayTimer?.invalidate()
        locationDisplayTimer = nil
        locationInfoText = ""
    }
}
