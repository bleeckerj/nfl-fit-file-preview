import XCTest
import FITSwiftSDK

final class FITTimestampExpanderTests: XCTestCase {
    func testCompressedTimestampWithoutTimestampInDefinitionRollsOver() throws {
        let full = UInt32(1_000_000_027)
        let body: [UInt8] = [0x40, 0, 0, 20, 0, 3, 253, 4, 0x86, 0, 4, 0x85, 1, 4, 0x85]
            + [0] + little(full) + little(0) + little(0)
            + [0x41, 0, 0, 20, 0, 2, 0, 4, 0x85, 1, 4, 0x85]
            + [0xA0 | UInt8((full + 6) & 31)] + little(0) + little(100)
            + [0xA0 | UInt8((full + 10) & 31)] + little(0) + little(200)
        let expanded = try FITTimestampExpander.expand(file(body))
        let listener = FitListener()
        let decoder = Decoder(stream: FITSwiftSDK.InputStream(data: expanded))
        decoder.addMesgListener(listener)
        try decoder.read()
        XCTAssertEqual(listener.fitMessages.recordMesgs.map { $0.getTimestamp()?.timestamp }, [full, full + 6, full + 10])
        let route = try FITRouteDecoder.decode(data: file(body), filename: "compressed.fit")
        XCTAssertEqual(route.pointCount, 3)
        XCTAssertEqual(route.start?.latitude, 0)
    }

    func testCompressedTimestampWithTimestampFieldAndBigEndian() throws {
        let full = UInt32(1_000_000_000)
        let body: [UInt8] = [0x40, 0, 1, 0, 20, 3, 253, 4, 0x86, 0, 4, 0x85, 1, 4, 0x85]
            + [0] + little(full).reversed() + little(0) + little(0)
            + [0x80 | UInt8((full + 1) & 31)] + little(0) + little(100).reversed()
        let route = try FITRouteDecoder.decode(data: file(body), filename: "big-endian.fit")
        XCTAssertEqual(route.pointCount, 2)
        XCTAssertEqual(try XCTUnwrap(route.end).longitude, Double(100) * 180 / 2_147_483_648, accuracy: 0.000001)
    }

    func testDeveloperPayloadIsPreservedDuringExpansion() throws {
        let full = UInt32(1_000_000_000)
        let body: [UInt8] = [0x40, 0, 0, 20, 0, 1, 253, 4, 0x86]
            + [0] + little(full)
            + [0x61, 0, 0, 20, 0, 1, 0, 4, 0x85, 1, 7, 2, 0]
            + [0xA1] + little(0) + [0xAB, 0xCD]
        let expanded = try FITTimestampExpander.expand(file(body))
        XCTAssertEqual(Array(expanded.suffix(4).prefix(2)), [0xAB, 0xCD])
        XCTAssertTrue(try Decoder(stream: FITSwiftSDK.InputStream(data: expanded)).checkIntegrity())
    }

    func testMalformedDefinitionsAndMissingTimestampReferenceAreRejected() throws {
        let bodies: [[UInt8]] = [
            [0x80],
            [0x40, 0, 0, 20, 0, 1, 0, 4],
            [0x40, 0, 2, 20, 0, 0],
            [0x40, 0, 0, 20, 0, 1, 0, 3, 0x85],
            [0x40, 0, 0, 20, 0, 1, 0, 4, 0xFF],
            [0x40, 0, 0, 20, 0, 1, 0, 4, 0x85, 0]
        ]
        for body in bodies {
            XCTAssertThrowsError(try FITTimestampExpander.expand(file(body)))
        }
    }

    private func little(_ value: UInt32) -> [UInt8] {
        (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
    }

    private func file(_ body: [UInt8]) -> Data {
        let header: [UInt8] = [12, 0x20, 0, 0] + little(UInt32(body.count)) + Array(".FIT".utf8)
        let bytes = header + body
        let checksum = FITTimestampExpander.crc(bytes)
        return Data(bytes + [UInt8(truncatingIfNeeded: checksum), UInt8(truncatingIfNeeded: checksum >> 8)])
    }
}
