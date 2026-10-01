import Foundation
import FITSwiftSDK

/// Expands compressed timestamps for Garmin's Swift decoder, which currently rejects them.
/// Reference: https://developer.garmin.com/fit/articles/fit-protocol/fit_protocol.html
enum FITTimestampExpander {
    private struct Field {
        let number: UInt8
        let size: Int
        let baseType: UInt8
    }

    private struct Definition {
        let header: UInt8
        let prefix: [UInt8]
        let fields: [Field]
        let developerDefinition: [UInt8]
        let developerSize: Int
        let bigEndian: Bool
        var injectedTimestamp = false

        var timestamp: Field? { fields.first { $0.number == 253 } }

        var bytes: [UInt8] {
            var result = [header] + prefix
            result.append(UInt8(fields.count + (injectedTimestamp ? 1 : 0)))
            for field in fields { result += [field.number, UInt8(field.size), field.baseType] }
            if injectedTimestamp { result += [253, 4, 0x86] }
            return result + developerDefinition
        }
    }

    static func expand(_ data: Data) throws -> Data {
        guard data.count <= FITRouteDecoder.maximumFileSize else { throw FITPreviewError.tooLarge }
        var result = Data()
        var offset = 0
        while offset < data.count {
            try Task.checkCancellation()
            guard data.count - offset >= 14 else { throw FITPreviewError.malformed }
            let headerSize = Int(data[offset])
            guard [12, 14].contains(headerSize), data.count - offset >= headerSize + 2,
                  Array(data[(offset + 8)..<(offset + 12)]) == Array(".FIT".utf8) else {
                throw FITPreviewError.malformed
            }
            let size = (0..<4).reduce(0) { $0 | (Int(data[offset + 4 + $1]) << ($1 * 8)) }
            let length = headerSize + size + 2
            guard length <= data.count - offset else { throw FITPreviewError.malformed }
            let file = data.subdata(in: offset..<(offset + length))
            guard try Decoder(stream: FITSwiftSDK.InputStream(data: file)).checkIntegrity() else {
                throw FITPreviewError.malformed
            }
            let body = try expandRecords(Array(file[headerSize..<(headerSize + size)]))
            var header = Array(file.prefix(headerSize))
            for index in 0..<4 { header[4 + index] = UInt8(truncatingIfNeeded: body.count >> (index * 8)) }
            if headerSize == 14 {
                let checksum = crc(header.prefix(12))
                header[12] = UInt8(truncatingIfNeeded: checksum)
                header[13] = UInt8(truncatingIfNeeded: checksum >> 8)
            }
            let normalized = header + body
            let checksum = crc(normalized)
            result.append(contentsOf: normalized)
            result.append(UInt8(truncatingIfNeeded: checksum))
            result.append(UInt8(truncatingIfNeeded: checksum >> 8))
            guard result.count <= FITRouteDecoder.maximumFileSize * 2 else { throw FITPreviewError.tooLarge }
            offset += length
        }
        return result
    }

    private static func expandRecords(_ bytes: [UInt8]) throws -> [UInt8] {
        var cursor = 0
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var definitions: [UInt8: Definition] = [:]
        var lastTimestamp: UInt32?
        let typeSizes = [1, 1, 1, 2, 2, 4, 4, 1, 4, 8, 1, 2, 4, 1, 8, 8, 8]

        func take(_ count: Int) throws -> [UInt8] {
            guard count >= 0, count <= bytes.count - cursor else { throw FITPreviewError.malformed }
            defer { cursor += count }
            return Array(bytes[cursor..<(cursor + count)])
        }

        while cursor < bytes.count {
            try Task.checkCancellation()
            let header = try take(1)[0]
            let compressed = header & 0x80 != 0
            let local = compressed ? (header >> 5) & 3 : header & 15
            if !compressed && header & 0x40 != 0 {
                guard header & 0x10 == 0 else { throw FITPreviewError.malformed }
                let prefix = try take(4)
                guard prefix[0] == 0, prefix[1] <= 1 else { throw FITPreviewError.malformed }
                let count = Int(try take(1)[0])
                var fields: [Field] = []
                for _ in 0..<count {
                    let values = try take(3)
                    let type = Int(values[2] & 0x1F)
                    let size = Int(values[1])
                    guard type < typeSizes.count, size > 0, size % typeSizes[type] == 0,
                          !fields.contains(where: { $0.number == values[0] }) else {
                        throw FITPreviewError.malformed
                    }
                    if values[0] == 253 {
                        guard size == 4, type == 6 else { throw FITPreviewError.malformed }
                    }
                    fields.append(Field(number: values[0], size: size, baseType: values[2]))
                }
                var developerDefinition: [UInt8] = []
                var developerSize = 0
                if header & 0x20 != 0 {
                    let developerCount = try take(1)[0]
                    developerDefinition.append(developerCount)
                    for _ in 0..<developerCount {
                        let values = try take(3)
                        guard values[1] > 0 else { throw FITPreviewError.malformed }
                        developerSize += Int(values[1])
                        developerDefinition += values
                    }
                }
                let definition = Definition(header: header, prefix: prefix, fields: fields,
                                            developerDefinition: developerDefinition,
                                            developerSize: developerSize, bigEndian: prefix[1] == 1)
                definitions[local] = definition
                output += definition.bytes
                continue
            }
            guard compressed || header & 0x70 == 0,
                  var definition = definitions[local] else { throw FITPreviewError.malformed }
            var timestamp: UInt32?
            if compressed {
                guard let previous = lastTimestamp else { throw FITPreviewError.malformed }
                let offset = UInt32(header & 31)
                let increment = (offset &- (previous & 31)) & 31
                let (value, overflow) = previous.addingReportingOverflow(increment)
                guard !overflow, value != UInt32.max else { throw FITPreviewError.malformed }
                timestamp = value
                lastTimestamp = value
                if definition.timestamp == nil && !definition.injectedTimestamp {
                    guard definition.fields.count < 255 else { throw FITPreviewError.malformed }
                    definition.injectedTimestamp = true
                    definitions[local] = definition
                    output += definition.bytes
                }
            }
            output.append(local)
            for field in definition.fields {
                if compressed && field.number == 253 {
                    output += timestampBytes(timestamp!, bigEndian: definition.bigEndian)
                } else {
                    let value = try take(field.size)
                    output += value
                    if field.number == 253 {
                        let ordered = definition.bigEndian ? Array(value.reversed()) : value
                        let full = (0..<4).reduce(UInt32(0)) { $0 | (UInt32(ordered[$1]) << ($1 * 8)) }
                        if full != UInt32.max { lastTimestamp = full }
                    }
                }
            }
            if definition.injectedTimestamp {
                output += timestampBytes(timestamp ?? UInt32.max, bigEndian: definition.bigEndian)
            }
            output += try take(definition.developerSize)
            guard output.count <= FITRouteDecoder.maximumFileSize * 2 else { throw FITPreviewError.tooLarge }
        }
        return output
    }

    private static func timestampBytes(_ value: UInt32, bigEndian: Bool) -> [UInt8] {
        let bytes = (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
        return bigEndian ? bytes.reversed() : bytes
    }

    static func crc<T: Sequence>(_ bytes: T) -> UInt16 where T.Element == UInt8 {
        var checksum: UInt16 = 0
        for byte in bytes {
            checksum ^= UInt16(byte)
            for _ in 0..<8 {
                checksum = checksum & 1 == 0 ? checksum >> 1 : (checksum >> 1) ^ 0xA001
            }
        }
        return checksum
    }
}
