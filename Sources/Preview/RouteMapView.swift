import AppKit
import MapKit

final class RouteMapView: NSView, MKMapViewDelegate {
    private let map = MKMapView()
    private let status = NSTextField(labelWithString: "")
    private var routeBounds: RouteBounds?
    private var loadTimeout: DispatchWorkItem?

    override init(frame: NSRect) {
        super.init(frame: frame)
        map.delegate = self
        map.mapType = .standard
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.showsZoomControls = true
        map.showsCompass = false
        map.showsUserLocation = false
        map.setAccessibilityLabel("Recorded route map")
        map.translatesAutoresizingMaskIntoConstraints = false
        status.translatesAutoresizingMaskIntoConstraints = false
        status.font = .systemFont(ofSize: 12)
        status.textColor = .labelColor
        status.drawsBackground = true
        status.backgroundColor = .windowBackgroundColor
        status.isHidden = true
        addSubview(map)
        addSubview(status)
        NSLayoutConstraint.activate([
            map.leadingAnchor.constraint(equalTo: leadingAnchor),
            map.trailingAnchor.constraint(equalTo: trailingAnchor),
            map.topAnchor.constraint(equalTo: topAnchor),
            map.bottomAnchor.constraint(equalTo: bottomAnchor),
            status.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            status.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            status.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func display(_ summary: RouteSummary) {
        reset()
        routeBounds = RouteBounds(segments: summary.segments)
        for segment in summary.segments where segment.count > 1 {
            map.addOverlay(RouteMapGeometry.polyline(for: segment))
        }
        if let start = summary.start { addMarker(start, title: "Start") }
        if let end = summary.end, summary.pointCount > 1 { addMarker(end, title: "Finish") }
        map.setAccessibilityLabel("Recorded route map, \(summary.pointCount) GPS points")
        fitRoute()
        let timeout = DispatchWorkItem { [weak self] in
            self?.showStatus("Basemap unavailable. Route and recorded stats remain available.")
        }
        loadTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
    }

    func reset() {
        loadTimeout?.cancel()
        loadTimeout = nil
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)
        routeBounds = nil
        status.isHidden = true
    }

    func fitRoute() {
        guard let bounds = routeBounds else { return }
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: bounds.centerLatitude, longitude: bounds.centerLongitude),
            span: MKCoordinateSpan(latitudeDelta: min(170, bounds.latitudeSpan * 1.25),
                                   longitudeDelta: min(360, bounds.longitudeSpan * 1.25)))
        let fitted = map.regionThatFits(region)
        map.setRegion(fitted, animated: false)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = .systemBlue
        renderer.lineWidth = 4
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
        let isStart = annotation.title == "Start"
        view.markerTintColor = isStart ? .systemGreen : .systemRed
        view.glyphText = isStart ? "S" : "F"
        view.titleVisibility = .visible
        view.displayPriority = .required
        view.canShowCallout = true
        return view
    }

    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        loadTimeout?.cancel()
        status.isHidden = true
    }

    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        if fullyRendered {
            loadTimeout?.cancel()
            status.isHidden = true
        }
    }

    func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
        loadTimeout?.cancel()
        showStatus("Basemap unavailable. Route and recorded stats remain available.")
    }

    private func addMarker(_ point: RouteCoordinate, title: String) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        annotation.title = title
        map.addAnnotation(annotation)
    }

    private func showStatus(_ message: String) {
        status.stringValue = message
        status.isHidden = false
    }
}
