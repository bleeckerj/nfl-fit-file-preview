import Foundation

enum RouteFileDecoder {
    static func decode(url: URL) throws -> RouteSummary {
        switch url.pathExtension.lowercased() {
        case "gpx": return try GPXRouteDecoder.decode(url: url)
        default: return try FITRouteDecoder.decode(url: url)
        }
    }
}
