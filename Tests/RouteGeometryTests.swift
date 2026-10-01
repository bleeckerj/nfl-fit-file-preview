import XCTest

final class RouteGeometryTests: XCTestCase {
    func testDateLineUsesNarrowGeographicBounds() throws {
        let bounds = try XCTUnwrap(RouteBounds(segments: [[
            RouteCoordinate(latitude: 10, longitude: 179)!,
            RouteCoordinate(latitude: 11, longitude: -179)!
        ]]))
        XCTAssertEqual(abs(bounds.centerLongitude), 180)
        XCTAssertEqual(bounds.longitudeSpan, 2)
        XCTAssertEqual(bounds.latitudeSpan, 1)
    }

    func testNormalRouteAndSinglePointBounds() throws {
        let bounds = try XCTUnwrap(RouteBounds(segments: [[
            RouteCoordinate(latitude: 34, longitude: -118)!,
            RouteCoordinate(latitude: 35, longitude: -117)!
        ]]))
        XCTAssertEqual(bounds.centerLongitude, -117.5)
        XCTAssertEqual(bounds.centerLatitude, 34.5)
        let single = try XCTUnwrap(RouteBounds(segments: [[RouteCoordinate(latitude: 0, longitude: 0)!]]))
        XCTAssertGreaterThan(single.latitudeSpan, 0)
        XCTAssertGreaterThan(single.longitudeSpan, 0)
        XCTAssertNil(RouteBounds(segments: []))
    }

    func testInvalidGeographicCoordinatesAreRejected() {
        XCTAssertNil(RouteCoordinate(latitude: .nan, longitude: 0))
        XCTAssertNil(RouteCoordinate(latitude: 91, longitude: 0))
        XCTAssertNil(RouteCoordinate(latitude: 0, longitude: 181))
        XCTAssertNotNil(RouteCoordinate(latitude: 0, longitude: 0))
    }
}
