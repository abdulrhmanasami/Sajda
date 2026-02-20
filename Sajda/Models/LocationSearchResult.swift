
import Foundation
import CoreLocation

struct LocationSearchResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let country: String
    let coordinates: CLLocationCoordinate2D

    // R3-4: Include coordinates to avoid deduplicating different locations with same name
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(country)
        hasher.combine((coordinates.latitude * 10000).rounded())
        hasher.combine((coordinates.longitude * 10000).rounded())
    }

    static func == (lhs: LocationSearchResult, rhs: LocationSearchResult) -> Bool {
        return lhs.name == rhs.name
            && lhs.country == rhs.country
            && (lhs.coordinates.latitude * 10000).rounded() == (rhs.coordinates.latitude * 10000).rounded()
            && (lhs.coordinates.longitude * 10000).rounded() == (rhs.coordinates.longitude * 10000).rounded()
    }
}
