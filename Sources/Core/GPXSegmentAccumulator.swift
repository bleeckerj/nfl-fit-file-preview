import Foundation

/// Measures only adjacent valid points within each GPX segment.
struct GPXSegmentAccumulator {
    private(set) var segments: [[RouteCoordinate]] = []
    private var current: [RouteCoordinate] = []
    private var previousDate: Date?
    private var completeTimes = true
    private var elapsed = 0.0
    private var timedEdges = 0
    private(set) var firstDate: Date?
    private(set) var pointCount = 0
    private(set) var distance = 0.0

    var duration: Double? { completeTimes && timedEdges > 0 ? elapsed : nil }

    mutating func append(_ coordinate: RouteCoordinate?, date: Date?) {
        guard let coordinate else { split(); return }
        if firstDate == nil { firstDate = date }
        if let previous = current.last {
            distance += Self.distance(from: previous, to: coordinate)
            if let previousDate, let date, date >= previousDate {
                elapsed += date.timeIntervalSince(previousDate)
                timedEdges += 1
            } else {
                completeTimes = false
            }
        }
        if date == nil { completeTimes = false }
        previousDate = date
        current.append(coordinate)
        pointCount += 1
    }

    mutating func split() {
        if !current.isEmpty { segments.append(current) }
        current.removeAll(keepingCapacity: true)
        previousDate = nil
    }

    private static func distance(from a: RouteCoordinate, to b: RouteCoordinate) -> Double {
        let radians = Double.pi / 180
        let latitude = (b.latitude - a.latitude) * radians
        let longitude = (b.longitude - a.longitude) * radians
        let haversine = pow(sin(latitude / 2), 2)
            + cos(a.latitude * radians) * cos(b.latitude * radians) * pow(sin(longitude / 2), 2)
        return 6_371_008.8 * 2 * asin(sqrt(min(1, max(0, haversine))))
    }
}
