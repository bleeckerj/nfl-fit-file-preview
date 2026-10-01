import XCTest
import MapKit

final class RouteMapGeometryTests: XCTestCase {
    func testDateLinePolylineTakesShortPath() {
        for longitudes in [[179.0, -179.0], [-179.0, 179.0]] {
            let polyline = RouteMapGeometry.polyline(for: longitudes.map {
                RouteCoordinate(latitude: 10, longitude: $0)!
            })
            XCTAssertEqual(polyline.pointCount, 2)
            XCTAssertLessThan(polyline.boundingMapRect.width, MKMapSize.world.width / 100)
        }
    }

    func testPolylineRetainsCompleteOrdinaryRoute() {
        let points = (0..<100).map {
            RouteCoordinate(latitude: 34 + Double($0) / 10000, longitude: -118)!
        }
        let polyline = RouteMapGeometry.polyline(for: points)
        XCTAssertEqual(polyline.pointCount, points.count)
        XCTAssertGreaterThan(polyline.boundingMapRect.height, 0)
    }

    func testElapsedDurationIsLabeledAndMissingStatsStayAbsent() {
        let elapsed = RouteSummary(filename: "ride.fit", segments: [], date: nil,
                                   distanceMeters: nil, durationSeconds: 100, durationIsElapsed: true)
        XCTAssertTrue(SummaryFormatter.details(for: elapsed).contains("Elapsed:"))
        let missing = RouteSummary(filename: "settings.fit", segments: [], date: nil,
                                   distanceMeters: nil, durationSeconds: nil, durationIsElapsed: false)
        XCTAssertEqual(SummaryFormatter.details(for: missing), "No recorded summary available")
    }
}
