import CoreGraphics

public struct MapProjection {
    public let size: CGSize
    public let minLat: Double
    public let maxLat: Double

    public init(size: CGSize, latitudeRange: ClosedRange<Double> = -70...70) {
        self.size = size
        self.minLat = latitudeRange.lowerBound
        self.maxLat = latitudeRange.upperBound
    }

    public func project(longitude lon: Double, latitude lat: Double) -> CGPoint {
        let clampedLat = max(minLat, min(maxLat, lat))
        let latSpan = maxLat - minLat
        let x = (lon + 180) / 360 * size.width
        let y = (maxLat - clampedLat) / latSpan * size.height
        return CGPoint(x: x, y: y)
    }

    public func pathForRing(_ ring: [[Double]]) -> CGPath {
        let path = CGMutablePath()
        guard let first = ring.first, first.count >= 2 else { return path }
        let start = project(longitude: first[0], latitude: first[1])
        path.move(to: start)
        for coord in ring.dropFirst() {
            guard coord.count >= 2 else { continue }
            path.addLine(to: project(longitude: coord[0], latitude: coord[1]))
        }
        path.closeSubpath()
        return path
    }

    public func pathsForFeature(_ feature: GeoJSONFeature) -> [CGPath] {
        feature.polygons.map { pathForRing($0) }
    }
}
