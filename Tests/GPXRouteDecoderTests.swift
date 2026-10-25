import XCTest

final class GPXRouteDecoderTests: XCTestCase {
    func testTrackCoordinatesEstimatedDistanceAndElapsedTime() throws {
        let route = try decode("""
        <metadata><time>2020-01-01T00:00:00Z</time></metadata>
        <trk><trkseg>
        <trkpt lat="0" lon="0"><time>2026-10-25T12:00:00.500Z</time></trkpt>
        <trkpt lat="0" lon="1"><time>2026-10-25T12:10:00.500Z</time></trkpt>
        </trkseg></trk>
        """)
        XCTAssertEqual(route.filename, "sample.gpx")
        XCTAssertEqual(route.start, RouteCoordinate(latitude: 0, longitude: 0))
        XCTAssertEqual(route.end, RouteCoordinate(latitude: 0, longitude: 1))
        XCTAssertEqual(try XCTUnwrap(route.distanceMeters), 111_195, accuracy: 1)
        XCTAssertEqual(route.durationSeconds, 600)
        XCTAssertTrue(route.durationIsElapsed)
        XCTAssertTrue(route.distanceIsEstimated)
        XCTAssertEqual(route.date?.timeIntervalSince1970, 1_792_929_600.5)
        XCTAssertTrue(SummaryFormatter.details(for: route).contains("Approx."))
        XCTAssertTrue(SummaryFormatter.details(for: route).contains("Elapsed:"))
    }

    func testSegmentAndTrackBoundariesExcludeConnectingDistanceAndTime() throws {
        let route = try decode("""
        <trk><trkseg>
        <trkpt lat="0" lon="0"><time>2026-10-25T12:00:00Z</time></trkpt>
        <trkpt lat="0" lon="0.001"><time>2026-10-25T12:01:00Z</time></trkpt>
        </trkseg><trkseg>
        <trkpt lat="40" lon="40"><time>2026-10-26T12:00:00Z</time></trkpt>
        <trkpt lat="40" lon="40"><time>2026-10-26T12:02:00Z</time></trkpt>
        </trkseg></trk><trk><trkseg><trkpt lat="80" lon="80"/></trkseg></trk>
        """)
        XCTAssertEqual(route.segments.map(\.count), [2, 2, 1])
        XCTAssertEqual(try XCTUnwrap(route.distanceMeters), 111.195, accuracy: 0.01)
        XCTAssertNil(route.durationSeconds, "Incomplete timestamps must not produce a partial total")
        let timed = try decode("""
        <trk><trkseg>
        <trkpt lat="0" lon="0"><time>2026-10-25T12:00:00Z</time></trkpt>
        <trkpt lat="0" lon="1"><time>2026-10-25T12:01:00Z</time></trkpt>
        </trkseg><trkseg>
        <trkpt lat="0" lon="2"><time>2026-10-26T12:00:00Z</time></trkpt>
        <trkpt lat="0" lon="3"><time>2026-10-26T12:02:00Z</time></trkpt>
        </trkseg></trk>
        """)
        XCTAssertEqual(timed.durationSeconds, 180)
    }

    func testRoutesWithoutTimesAndTrackPreference() throws {
        let body = "<rte><rtept lat=\"1\" lon=\"2\"/><rtept lat=\"1\" lon=\"3\"/></rte>"
        let route = try decode(body + body)
        XCTAssertEqual(route.segments.map(\.count), [2, 2])
        XCTAssertNil(route.durationSeconds)
        let track = try decode(body + "<trk><trkseg><trkpt lat=\"5\" lon=\"6\"/></trkseg></trk>")
        XCTAssertEqual(track.pointCount, 1)
        XCTAssertEqual(track.start, RouteCoordinate(latitude: 5, longitude: 6))
        XCTAssertNil(track.distanceMeters)
    }

    func testInvalidCoordinatesSplitRatherThanBridgeGaps() throws {
        let route = try decode("""
        <trk><trkseg><trkpt lat="0" lon="0"/><trkpt lat="91" lon="2"/>
        <trkpt lat="0" lon="1"/><trkpt lat="NaN" lon="2"/>
        <trkpt lat="0"/><trkpt lat="0" lon="2"/></trkseg></trk>
        """)
        XCTAssertEqual(route.segments.map(\.count), [1, 1, 1])
        XCTAssertEqual(route.distanceMeters, 0)
    }

    func testGPX10AndPrefixedNamespacesAndTimezoneOffsets() throws {
        let xml = """
        <g:gpx xmlns:g="http://www.topografix.com/GPX/1/0" version="1.0" creator="test">
        <g:time>2026-10-25T05:00:00-07:00</g:time>
        <g:rte><g:rtept lat="34" lon="-118"/></g:rte></g:gpx>
        """
        let route = try GPXRouteDecoder.decode(data: Data(xml.utf8), filename: "old.GPX")
        XCTAssertEqual(route.pointCount, 1)
        XCTAssertEqual(route.date?.timeIntervalSince1970, 1_792_929_600)
        XCTAssertNil(route.durationSeconds)
    }

    func testExtensionsCannotInjectPointsOrTimestamps() throws {
        let route = try decode("""
        <extensions><trk><trkseg><trkpt lat="1" lon="1"/></trkseg></trk></extensions>
        <trk><trkseg><trkpt lat="0" lon="0">
        <extensions><time>2026-10-25T12:00:00Z</time></extensions>
        <time xmlns="https://example.com/extension">2026-10-25T12:00:00Z</time>
        </trkpt><trkpt lat="0" lon="1"/></trkseg></trk>
        """)
        XCTAssertEqual(route.pointCount, 2)
        XCTAssertNil(route.date)
        XCTAssertNil(route.durationSeconds)
    }

    func testEmptyAndWaypointOnlyGPXHaveNoConnectedRoute() throws {
        for body in ["", "<wpt lat=\"1\" lon=\"2\"/><wpt lat=\"3\" lon=\"4\"/>"] {
            let route = try decode(body)
            XCTAssertTrue(route.segments.isEmpty)
            XCTAssertNil(route.distanceMeters)
            XCTAssertNil(route.durationSeconds)
        }
    }

    func testMissingInvalidOrReversedTimesOmitDuration() throws {
        for time in ["", "<time>invalid</time>", "<time>2026-10-24T00:00:00Z</time>"] {
            let route = try decode("""
            <rte><rtept lat="0" lon="0"><time>2026-10-25T00:00:00Z</time></rtept>
            <rtept lat="0" lon="1">\(time)</rtept></rte>
            """)
            XCTAssertNil(route.durationSeconds)
        }
    }

    func testDateLineUsesShortDistanceAndExistingBounds() throws {
        let route = try decode("<rte><rtept lat=\"0\" lon=\"179.9\"/><rtept lat=\"0\" lon=\"-179.9\"/></rte>")
        XCTAssertEqual(try XCTUnwrap(route.distanceMeters), 22_239, accuracy: 1)
        XCTAssertLessThan(try XCTUnwrap(RouteBounds(segments: route.segments)).longitudeSpan, 1)
    }

    func testMalformedForeignAndEntityDocumentsAreRejected() {
        for xml in ["", "hello", "<gpx><trk>", "<html/>", "<gpx xmlns=\"https://example.com\"/>",
                    "<!DOCTYPE gpx [<!ENTITY x 'test'>]><gpx>&x;</gpx>",
                    "<gpx>" + String(repeating: "<extensions>", count: 65)
                        + String(repeating: "</extensions>", count: 65) + "</gpx>"] {
            XCTAssertThrowsError(try GPXRouteDecoder.decode(data: Data(xml.utf8), filename: "bad.gpx"), xml)
        }
    }

    func testExternalEntityContentsAreNeverLoaded() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("<rte><rtept lat=\"1\" lon=\"2\"/></rte>".utf8).write(to: file)
        let xml = "<!DOCTYPE gpx [<!ENTITY x SYSTEM '\(file.absoluteString)'>]><gpx>&x;</gpx>"
        let route = try GPXRouteDecoder.decode(data: Data(xml.utf8), filename: "external.gpx")
        XCTAssertEqual(route.pointCount, 0)
    }

    func testLargeRecordingRetainsAllPoints() throws {
        let point = "<trkpt lat=\"34\" lon=\"-118\"/>"
        let route = try decode("<trk><trkseg>" + String(repeating: point, count: 25_000) + "</trkseg></trk>")
        XCTAssertEqual(route.pointCount, 25_000)
    }

    func testOversizedDataIsRejected() {
        XCTAssertThrowsError(try GPXRouteDecoder.decode(
            data: Data(count: GPXRouteDecoder.maximumFileSize + 1), filename: "large.gpx")) { error in
            guard case GPXPreviewError.tooLarge = error else { return XCTFail("Expected size limit") }
        }
    }

    func testCancelledDecodeStopsBeforeReading() async {
        let task = Task { () throws -> RouteSummary in
            while !Task.isCancelled { await Task.yield() }
            return try GPXRouteDecoder.decode(data: Data("<gpx/>".utf8), filename: "cancel.gpx")
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testFileDispatchSupportsUppercaseGPXAndPreservesFIT() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let gpx = folder.appendingPathComponent("test.GPX")
        try Data("<gpx><rte><rtept lat=\"0\" lon=\"0\"/></rte></gpx>".utf8).write(to: gpx)
        XCTAssertEqual(try RouteFileDecoder.decode(url: gpx).pointCount, 1)
        let fit = folder.appendingPathComponent("test.FIT")
        try FITFixture.file([FITFixture.record()]).write(to: fit)
        XCTAssertEqual(try RouteFileDecoder.decode(url: fit).pointCount, 1)
        XCTAssertThrowsError(try RouteFileDecoder.decode(url: folder.appendingPathComponent("missing.gpx")))
    }

    private func decode(_ body: String) throws -> RouteSummary {
        let xml = "<gpx xmlns=\"http://www.topografix.com/GPX/1/1\" version=\"1.1\" creator=\"test\">\(body)</gpx>"
        return try GPXRouteDecoder.decode(data: Data(xml.utf8), filename: "sample.gpx")
    }
}
