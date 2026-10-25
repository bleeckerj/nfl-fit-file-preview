import Foundation

enum GPXPreviewError: LocalizedError {
    case unreadable, malformed, tooLarge

    var errorDescription: String? {
        switch self {
        case .unreadable: return "This GPX file could not be read."
        case .malformed: return "This file is incomplete or is not a valid GPX document."
        case .tooLarge: return "This GPX file is too large to preview. The limit is 100 MB."
        }
    }
}

enum GPXRouteDecoder {
    static let maximumFileSize = 100 * 1024 * 1024

    static func decode(url: URL) throws -> RouteSummary {
        try Task.checkCancellation()
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= maximumFileSize else { throw GPXPreviewError.tooLarge }
            data = try Data(contentsOf: url)
        } catch let error as GPXPreviewError {
            throw error
        } catch {
            throw GPXPreviewError.unreadable
        }
        return try decode(data: data, filename: url.lastPathComponent)
    }

    static func decode(data: Data, filename: String) throws -> RouteSummary {
        try Task.checkCancellation()
        guard data.count <= maximumFileSize else { throw GPXPreviewError.tooLarge }
        let parser = XMLParser(data: data)
        let listener = GPXRouteListener()
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = listener
        let parsed = parser.parse()
        try Task.checkCancellation()
        guard parsed, listener.validRoot, !listener.rejected else { throw GPXPreviewError.malformed }
        return listener.summary(filename: filename)
    }
}

private final class GPXRouteListener: NSObject, XMLParserDelegate {
    private var path: [String] = []
    private var namespace = ""
    private var tracks = GPXSegmentAccumulator()
    private var routes = GPXSegmentAccumulator()
    private var metadataDate: Date?
    private var coordinate: RouteCoordinate?
    private var pointDate: Date?
    private var timeText = ""
    private var collectingTime = false
    private let dates = ISO8601DateFormatter()
    private let fractionalDates: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private(set) var validRoot = false
    private(set) var rejected = false

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        guard !Task.isCancelled else { parser.abortParsing(); return }
        guard path.count < 64 else { reject(parser); return }
        if path.isEmpty {
            namespace = namespaceURI ?? ""
            validRoot = name == "gpx" && ["", "http://www.topografix.com/GPX/1/0",
                                         "http://www.topografix.com/GPX/1/1"].contains(namespace)
            guard validRoot else { reject(parser); return }
        }
        path.append((namespaceURI ?? "") == namespace ? name : "")
        if isTrackPoint || isRoutePoint {
            coordinate = nil
            pointDate = nil
            if let latitude = attributes["lat"].flatMap(Double.init),
               let longitude = attributes["lon"].flatMap(Double.init) {
                coordinate = RouteCoordinate(latitude: latitude, longitude: longitude)
            }
        }
        collectingTime = isPointTime || path == ["gpx", "metadata", "time"] || path == ["gpx", "time"]
        if collectingTime { timeText = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !Task.isCancelled else { parser.abortParsing(); return }
        if collectingTime {
            guard timeText.utf8.count + string.utf8.count <= 256 else { reject(parser); return }
            timeText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        guard !Task.isCancelled else { parser.abortParsing(); return }
        if collectingTime {
            let text = timeText.trimmingCharacters(in: .whitespacesAndNewlines)
            let date = fractionalDates.date(from: text) ?? dates.date(from: text)
            if isPointTime { pointDate = date } else { metadataDate = date }
            collectingTime = false
        }
        if isTrackPoint { tracks.append(coordinate, date: pointDate) }
        if isRoutePoint { routes.append(coordinate, date: pointDate) }
        if path == ["gpx", "trk", "trkseg"] { tracks.split() }
        if path == ["gpx", "rte"] { routes.split() }
        path.removeLast()
    }

    // Refuse internal entities; the parser's .never policy suppresses external entity loading.
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        reject(parser)
    }

    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String,
                publicID: String?, systemID: String?) {
        reject(parser)
    }

    private var isTrackPoint: Bool { path == ["gpx", "trk", "trkseg", "trkpt"] }
    private var isRoutePoint: Bool { path == ["gpx", "rte", "rtept"] }
    private var isPointTime: Bool {
        path == ["gpx", "trk", "trkseg", "trkpt", "time"] || path == ["gpx", "rte", "rtept", "time"]
    }

    private func reject(_ parser: XMLParser) {
        rejected = true
        parser.abortParsing()
    }

    func summary(filename: String) -> RouteSummary {
        // Exports can contain a planned route alongside the actual track; display the track once.
        var selected = tracks.pointCount > 0 ? tracks : routes
        selected.split()
        return RouteSummary(filename: filename, segments: selected.segments,
                            date: selected.firstDate ?? metadataDate,
                            distanceMeters: selected.pointCount > 1 ? selected.distance : nil,
                            durationSeconds: selected.duration,
                            durationIsElapsed: true, distanceIsEstimated: true)
    }
}
