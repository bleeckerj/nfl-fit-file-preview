import AppKit
import MapKit

enum RouteExampleImage {
    static func write(summary: RouteSummary, snapshot: MKMapSnapshotter.Snapshot, to output: URL) throws {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1280,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw FITPreviewError.unreadable }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 1024, height: 1280).fill()
        snapshot.image.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1184))

        for segment in summary.segments where segment.count > 1 {
            let path = NSBezierPath()
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            for (index, coordinate) in segment.enumerated() {
                let point = snapshot.point(for: CLLocationCoordinate2D(
                    latitude: coordinate.latitude, longitude: coordinate.longitude))
                if index == 0 { path.move(to: point) } else { path.line(to: point) }
            }
            NSColor.white.setStroke()
            path.lineWidth = 9
            path.stroke()
            NSColor.systemBlue.setStroke()
            path.lineWidth = 5
            path.stroke()
        }
        if let point = summary.start { marker(point, color: .systemGreen, snapshot: snapshot) }
        if let point = summary.end { marker(point, color: .systemRed, snapshot: snapshot) }

        draw("FIT Preview", at: NSPoint(x: 28, y: 1244), font: .systemFont(ofSize: 23, weight: .semibold))
        draw(summary.filename, at: NSPoint(x: 28, y: 1218), font: .monospacedSystemFont(ofSize: 16, weight: .regular))
        draw(SummaryFormatter.details(for: summary), at: NSPoint(x: 28, y: 1196), font: .systemFont(ofSize: 13))
        NSGraphicsContext.restoreGraphicsState()

        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw FITPreviewError.unreadable
        }
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: output, options: .atomic)
    }

    private static func marker(_ coordinate: RouteCoordinate, color: NSColor, snapshot: MKMapSnapshotter.Snapshot) {
        let point = snapshot.point(for: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude))
        let circle = NSBezierPath(ovalIn: NSRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16))
        color.setFill()
        circle.fill()
        NSColor.white.setStroke()
        circle.lineWidth = 3
        circle.stroke()
    }

    private static func draw(_ text: String, at point: NSPoint, font: NSFont) {
        (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: NSColor.black])
    }
}
