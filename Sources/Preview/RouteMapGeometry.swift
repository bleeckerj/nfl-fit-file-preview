import MapKit

enum RouteMapGeometry {
    static func polyline(for segment: [RouteCoordinate]) -> MKPolyline {
        let worldWidth = MKMapSize.world.width
        var previousX: Double?
        let points = segment.map { coordinate -> MKMapPoint in
            var point = MKMapPoint(CLLocationCoordinate2D(latitude: coordinate.latitude,
                                                          longitude: coordinate.longitude))
            if let previousX {
                while point.x - previousX > worldWidth / 2 { point.x -= worldWidth }
                while point.x - previousX < -worldWidth / 2 { point.x += worldWidth }
            }
            previousX = point.x
            return point
        }
        return MKPolyline(points: points, count: points.count)
    }
}
