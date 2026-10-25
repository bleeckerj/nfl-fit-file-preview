import AppKit
import MapKit

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: export-route-example INPUT.fit OUTPUT.png\n", stderr)
    exit(2)
}

let inspectOnly = CommandLine.arguments[1] == "--inspect"
let source = URL(fileURLWithPath: CommandLine.arguments[inspectOnly ? 2 : 1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard inspectOnly || (output.pathExtension.lowercased() == "png" && source.standardizedFileURL != output.standardizedFileURL) else {
    fputs("Choose a separate .png output file; the source recording is read-only.\n", stderr)
    exit(2)
}

do {
    let summary = try FITRouteDecoder.decode(url: source)
    print("Decoded \(summary.filename): \(summary.pointCount) GPS points, \(summary.segments.count) segments")
    if inspectOnly {
        print(SummaryFormatter.details(for: summary))
        exit(0)
    }
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    guard let bounds = RouteBounds(segments: summary.segments) else {
        throw NSError(domain: "FITPreview.Export", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "The file contains no GPS route."])
    }
    let options = MKMapSnapshotter.Options()
    options.size = NSSize(width: 1024, height: 1184)
    options.appearance = NSAppearance(named: .aqua)
    options.mapType = .standard
    options.region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: bounds.centerLatitude, longitude: bounds.centerLongitude),
        span: MKCoordinateSpan(latitudeDelta: min(170, bounds.latitudeSpan * 1.5),
                               longitudeDelta: min(360, bounds.longitudeSpan * 1.5)))
    let snapshotter = MKMapSnapshotter(options: options)
    var completed = false
    var exportError: Error?
    snapshotter.start(with: .main) { snapshot, error in
        defer { completed = true }
        do {
            if let error { throw error }
            guard let snapshot else { throw FITPreviewError.unreadable }
            try RouteExampleImage.write(summary: summary, snapshot: snapshot, to: output)
            print("Saved \(output.path) (1024 × 1280)")
        } catch { exportError = error }
    }
    let deadline = Date().addingTimeInterval(90)
    while !completed && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }
    if !completed {
        snapshotter.cancel()
        throw NSError(domain: "FITPreview.Export", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Apple Maps snapshot timed out."])
    }
    if let exportError { throw exportError }
} catch {
    fputs("Export failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
