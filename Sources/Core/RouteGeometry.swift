import Foundation

/// The smallest longitude interval containing the route, including date-line crossings.
struct RouteBounds: Equatable {
    let centerLatitude: Double
    let centerLongitude: Double
    let latitudeSpan: Double
    let longitudeSpan: Double

    init?(segments: [[RouteCoordinate]]) {
        let points = segments.flatMap { $0 }
        guard let first = points.first else { return nil }
        var minLatitude = first.latitude
        var maxLatitude = first.latitude
        var longitudes = [Double]()
        longitudes.reserveCapacity(points.count)
        for point in points {
            minLatitude = min(minLatitude, point.latitude)
            maxLatitude = max(maxLatitude, point.latitude)
            longitudes.append(point.longitude < 0 ? point.longitude + 360 : point.longitude)
        }
        longitudes.sort()
        var largestGap = -Double.infinity
        var intervalStart = longitudes[0]
        for index in longitudes.indices {
            let next = index + 1 < longitudes.count ? longitudes[index + 1] : longitudes[0] + 360
            if next - longitudes[index] > largestGap {
                largestGap = next - longitudes[index]
                intervalStart = next.truncatingRemainder(dividingBy: 360)
            }
        }
        let width = 360 - largestGap
        let center = (intervalStart + width / 2).truncatingRemainder(dividingBy: 360)
        centerLatitude = (minLatitude + maxLatitude) / 2
        centerLongitude = center > 180 ? center - 360 : center
        latitudeSpan = max(0.005, maxLatitude - minLatitude)
        longitudeSpan = max(0.005, width)
    }
}

struct RouteSegmentBuilder {
    private(set) var segments: [[RouteCoordinate]] = []
    private var current: [RouteCoordinate] = []

    mutating func append(_ coordinate: RouteCoordinate?) {
        guard let coordinate else { split(); return }
        current.append(coordinate)
    }

    mutating func split() {
        if !current.isEmpty { segments.append(current) }
        current.removeAll(keepingCapacity: true)
    }

    mutating func finish() -> [[RouteCoordinate]] {
        split()
        return segments
    }
}
