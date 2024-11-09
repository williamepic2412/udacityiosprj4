import Foundation
import MapKit

/// Represents  a token that is returns when the user authenticates.
struct Token: Codable {
    let accessToken: String
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

/// Represents a trip.
struct Trip: Identifiable, Sendable, Hashable, Codable, Comparable {
    var id: Int
    var name: String
    var startDate: Date
    var endDate: Date
    var events: [Event]
    
    static func < (lhs: Trip, rhs: Trip) -> Bool {
        return lhs.startDate < rhs.startDate
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startDate = "start_date"
        case endDate = "end_date"
        case events
    }
}

/// Represents an event in a trip.
struct Event: Identifiable, Sendable, Hashable, Codable {
    var id: Int
    var name: String
    var note: String?
    var date: Date
    var location: Location?
    var medias: [Media]
    var transitionFromPrevious: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case note
        case date
        case location
        case medias
        case transitionFromPrevious = "transition_from_previous"
    }
}

/// Represents a location.
struct Location: Sendable, Hashable, Codable {
    var latitude: Double
    var longitude: Double
    var address: String?

    var coordinate: CLLocationCoordinate2D {
        return .init(latitude: latitude, longitude: longitude)
    }
}

/// Represents a media with a URL.
struct Media: Identifiable, Sendable, Hashable, Codable {
    var id: Int
    var url: URL?
}
