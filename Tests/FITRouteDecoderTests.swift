import XCTest
import FITSwiftSDK

final class FITRouteDecoderTests: XCTestCase {
    func testCoordinatesAndSessionTimerAreDecodedFromBinary() throws {
        let data = try FITFixture.file([
            FITFixture.record(latitude: 34.1, longitude: -118.2),
            FITFixture.record(latitude: 34.2, longitude: -118.3, seconds: 1_800_000),
            FITFixture.session()
        ])
        let route = try FITRouteDecoder.decode(data: data, filename: "ride.FIT")
        XCTAssertEqual(route.filename, "ride.FIT")
        XCTAssertEqual(route.pointCount, 2)
        XCTAssertEqual(try XCTUnwrap(route.start).latitude, 34.1, accuracy: 0.00001)
        XCTAssertEqual(try XCTUnwrap(route.end).longitude, -118.3, accuracy: 0.00001)
        XCTAssertEqual(route.durationSeconds, 600)
        XCTAssertFalse(route.durationIsElapsed)
        XCTAssertEqual(route.distanceMeters, 2000)
        XCTAssertEqual(route.date, FITFixture.start.date)
    }

    func testMissingGPSAndTimerStopsSplitSegments() throws {
        let stop = EventMesg()
        try stop.setEvent(.timer)
        try stop.setEventType(.stopAll)
        let data = try FITFixture.file([
            FITFixture.record(), FITFixture.record(latitude: nil, longitude: nil),
            FITFixture.record(), stop, FITFixture.record(), FITFixture.session(),
            FITFixture.record(), FITFixture.session(timer: 100)
        ])
        let route = try FITRouteDecoder.decode(data: data, filename: "segments.fit")
        XCTAssertEqual(route.segments.map(\.count), [1, 1, 1, 1])
        XCTAssertEqual(route.durationSeconds, 700)
        XCTAssertEqual(route.distanceMeters, 4000)
    }

    func testZeroCoordinatesAreValidAndSentinelsAreIgnored() throws {
        let invalid = try FITFixture.record()
        try invalid.setPositionLat(Int32.max)
        let route = try FITRouteDecoder.decode(data: FITFixture.file([
            FITFixture.record(latitude: 0, longitude: 0), invalid,
            FITFixture.record(latitude: 0, longitude: 1)
        ]), filename: "equator.fit")
        XCTAssertEqual(route.pointCount, 2)
        XCTAssertEqual(route.start, RouteCoordinate(latitude: 0, longitude: 0))
        XCTAssertEqual(route.segments.count, 2)
    }

    func testNoGPSReturnsStatsWithoutInventingARoute() throws {
        let route = try FITRouteDecoder.decode(data: FITFixture.file([
            FITFixture.record(latitude: nil, longitude: nil), FITFixture.session()
        ]), filename: "indoor.fit")
        XCTAssertTrue(route.segments.isEmpty)
        XCTAssertEqual(route.durationSeconds, 600)
    }

    func testCourseAndSinglePointNeedNoSession() throws {
        let route = try FITRouteDecoder.decode(data: FITFixture.file([
            FITFixture.record(distance: 1500)
        ], type: .course), filename: "course.fit")
        XCTAssertEqual(route.pointCount, 1)
        XCTAssertEqual(route.distanceMeters, 1500)
        XCTAssertNil(route.durationSeconds)
        XCTAssertNotNil(RouteBounds(segments: route.segments))
    }

    func testElapsedFallbackIsExplicitAndPartialTimersAreNotSummed() throws {
        let route = try FITRouteDecoder.decode(data: FITFixture.file([
            FITFixture.session(timer: 100, elapsed: 200),
            FITFixture.session(timer: nil, elapsed: 300)
        ]), filename: "multi.fit")
        XCTAssertEqual(route.durationSeconds, 500)
        XCTAssertTrue(route.durationIsElapsed)
    }

    func testNoDurationIsInferredFromRecordTimestampGaps() throws {
        let route = try FITRouteDecoder.decode(data: FITFixture.file([
            FITFixture.record(), FITFixture.record(seconds: 1_800_000)
        ]), filename: "paused.fit")
        XCTAssertNil(route.durationSeconds)
    }

    func testInvalidAndExtremeTimestampsDoNotOverflow() throws {
        let record = try FITFixture.record()
        try record.setTimestamp(DateTime(timestamp: 4_000_000_000))
        let route = try FITRouteDecoder.decode(data: FITFixture.file([record]), filename: "future.fit")
        XCTAssertEqual(route.date?.timeIntervalSince1970, 4_631_065_600)
    }

    func testTruncatedCorruptAndNonFITDataAreRejected() throws {
        let valid = try FITFixture.file([FITFixture.record()])
        var corrupt = valid
        corrupt[corrupt.count - 1] ^= 0xFF
        for data in [Data(), Data("hello".utf8), Data(valid.dropLast()), corrupt,
                     Data([255] + Array(repeating: 0, count: 30))] {
            XCTAssertThrowsError(try FITRouteDecoder.decode(data: data, filename: "bad.fit"))
        }
    }

    func testConcatenatedFITFilesAreDecodedAndTruncatedSecondFileIsRejected() throws {
        let one = try FITFixture.file([FITFixture.record(), FITFixture.session()])
        let two = one + one
        let route = try FITRouteDecoder.decode(data: two, filename: "combined.fit")
        XCTAssertEqual(route.pointCount, 2)
        XCTAssertEqual(route.segments.count, 2)
        XCTAssertThrowsError(try FITRouteDecoder.decode(data: Data(two.dropLast()), filename: "bad.fit"))
    }

    func testCancelledDecodeStopsBeforeReading() async throws {
        let data = try FITFixture.file([FITFixture.record()])
        let task = Task { () throws -> RouteSummary in
            while !Task.isCancelled { await Task.yield() }
            return try FITRouteDecoder.decode(data: data, filename: "cancel.fit")
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testLargeRecordingRetainsAllPoints() throws {
        let records = try (0..<25_000).map {
            try FITFixture.record(latitude: 34 + Double($0) / 1_000_000,
                                  seconds: UInt32($0)) as Mesg
        }
        let route = try FITRouteDecoder.decode(data: FITFixture.file(records), filename: "large.fit")
        XCTAssertEqual(route.pointCount, 25_000)
    }
}
