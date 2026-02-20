
import Foundation
import CoreLocation

struct LocationSearchResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let country: String
    let coordinates: CLLocationCoordinate2D

    // Hashable conformance by name and country
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(country)
    }

    // Equatable conformance
    static func == (lhs: LocationSearchResult, rhs: LocationSearchResult) -> Bool {
        return lhs.name == rhs.name && lhs.country == rhs.country
    }
}
