import Foundation

struct RouteCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    init?(latitude: Double, longitude: Double) {
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct RouteSummary: Sendable {
    let filename: String
    let segments: [[RouteCoordinate]]
    let date: Date?
    let distanceMeters: Double?
    let durationSeconds: Double?
    let durationIsElapsed: Bool
    var distanceIsEstimated = false

    var start: RouteCoordinate? { segments.first?.first }
    var end: RouteCoordinate? { segments.last?.last }
    var pointCount: Int { segments.reduce(0) { $0 + $1.count } }
}

enum FITPreviewError: LocalizedError {
    case unreadable
    case malformed
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .unreadable: return "This FIT file could not be read."
        case .malformed: return "This file is incomplete or is not a valid FIT recording."
        case .tooLarge: return "This FIT file is too large to preview. The limit is 100 MB."
        }
    }
}
