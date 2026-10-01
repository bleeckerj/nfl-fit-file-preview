import Foundation
import FITSwiftSDK

enum FITRouteDecoder {
    static let maximumFileSize = 100 * 1024 * 1024

    static func decode(url: URL) throws -> RouteSummary {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= maximumFileSize else { throw FITPreviewError.tooLarge }
            data = try Data(contentsOf: url)
        } catch let error as FITPreviewError {
            throw error
        } catch {
            throw FITPreviewError.unreadable
        }
        return try decode(data: data, filename: url.lastPathComponent)
    }

    static func decode(data: Data, filename: String) throws -> RouteSummary {
        try Task.checkCancellation()
        guard data.count <= maximumFileSize else { throw FITPreviewError.tooLarge }
        let listener = RouteListener()
        do {
            guard !data.isEmpty else { throw FITPreviewError.malformed }
            let normalized = try FITTimestampExpander.expand(data)
            let decoder = Decoder(stream: FITSwiftSDK.InputStream(data: normalized))
            decoder.addMesgListener(listener)
            try Task.checkCancellation()
            try decoder.read()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as FITPreviewError {
            throw error
        } catch {
            throw FITPreviewError.malformed
        }
        return listener.summary(filename: filename)
    }
}

private final class RouteListener: MesgListener {
    private var builder = RouteSegmentBuilder()
    private var firstDate: Date?
    private var sessionDates: [Date] = []
    private var sessionDistances: [Double?] = []
    private var timerDurations: [Double?] = []
    private var elapsedDurations: [Double?] = []
    private var recordDistance: Double?

    func onMesg(_ mesg: Mesg) throws {
        try Task.checkCancellation()
        switch mesg.mesgNum {
        case MesgNum.record.rawValue:
            let record = RecordMesg(mesg: mesg)
            if firstDate == nil { firstDate = date(record.getTimestamp()) }
            if let distance = nonnegative(record.getDistance()) {
                recordDistance = max(recordDistance ?? 0, distance)
            }
            guard let latitude = record.getPositionLat(), let longitude = record.getPositionLong(),
                  latitude != Int32.max, longitude != Int32.max else {
                builder.split()
                return
            }
            let degreesPerSemicircle = 180.0 / 2_147_483_648.0
            builder.append(RouteCoordinate(latitude: Double(latitude) * degreesPerSemicircle,
                                           longitude: Double(longitude) * degreesPerSemicircle))
        case MesgNum.session.rawValue:
            let session = SessionMesg(mesg: mesg)
            if let start = date(session.getStartTime()) { sessionDates.append(start) }
            sessionDistances.append(nonnegative(session.getTotalDistance()))
            timerDurations.append(nonnegative(session.getTotalTimerTime()))
            elapsedDurations.append(nonnegative(session.getTotalElapsedTime()))
            recordDistance = nil
            builder.split()
        case MesgNum.event.rawValue:
            let event = EventMesg(mesg: mesg)
            if event.getEvent() == .timer,
               let type = event.getEventType(),
               [.stop, .stopAll, .stopDisable, .stopDisableAll].contains(type) {
                builder.split()
            }
        default:
            break
        }
    }

    func summary(filename: String) -> RouteSummary {
        let timer = completeTotal(timerDurations)
        let elapsed = completeTotal(elapsedDurations)
        let distance = completeTotal(sessionDistances)
        // Record distance is used only for files without session summaries, such as courses.
        let fallbackDistance = sessionDistances.isEmpty ? recordDistance : nil
        return RouteSummary(filename: filename, segments: builder.finish(),
                            date: sessionDates.min() ?? firstDate,
                            distanceMeters: distance ?? fallbackDistance,
                            durationSeconds: timer ?? elapsed,
                            durationIsElapsed: timer == nil && elapsed != nil)
    }

    private func nonnegative(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private func date(_ value: DateTime?) -> Date? {
        guard let value, value.timestamp != DateTime.invalid else { return nil }
        return Date(timeIntervalSince1970: Double(value.timestamp) + Double(DateTime.unixEpochToFITEpoch))
    }

    private func completeTotal(_ values: [Double?]) -> Double? {
        guard !values.isEmpty, values.allSatisfy({ $0 != nil }) else { return nil }
        return values.compactMap { $0 }.reduce(0, +)
    }
}
