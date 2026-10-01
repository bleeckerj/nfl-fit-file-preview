import XCTest

final class RealRecordingTests: XCTestCase {
    func testLocalRecordingWhenProvided() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent(".build/Verification/activity.fit")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: file.path),
                         "Copy a real recording to .build/Verification/activity.fit to run integration verification.")
        let clock = ContinuousClock()
        let start = clock.now
        let route = try FITRouteDecoder.decode(url: file)
        XCTAssertGreaterThan(route.pointCount, 1)
        XCTAssertNotNil(RouteBounds(segments: route.segments))
        XCTAssertNotNil(route.date)
        print("Real FIT verification: \(route.pointCount) GPS points, \(route.segments.count) segments, decode \(clock.now - start)")
    }
}
