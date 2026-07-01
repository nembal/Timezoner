import Foundation

public struct GeoJSONFeatureCollection: Codable {
    public let features: [GeoJSONFeature]
}

public struct GeoJSONFeature: Codable {
    public let properties: GeoJSONProperties
    public let geometry: GeoJSONGeometry

    /// Normalized accessor: returns array of rings regardless of Polygon vs MultiPolygon.
    /// Each ring is [[lon, lat], [lon, lat], ...]
    public var polygons: [[[Double]]] {
        switch geometry.type {
        case "Polygon":
            return geometry.coordinates ?? []
        case "MultiPolygon":
            return geometry.multiCoordinates?.flatMap { $0 } ?? []
        default:
            return []
        }
    }
}

public struct GeoJSONProperties: Codable {
    public let tzid: String
}

public struct GeoJSONGeometry: Codable {
    public let type: String
    public let coordinates: [[[Double]]]?        // Polygon: [ring, ring, ...]
    public let multiCoordinates: [[[[Double]]]]? // MultiPolygon: [polygon, polygon, ...]

    enum CodingKeys: String, CodingKey {
        case type, coordinates
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        if type == "MultiPolygon" {
            multiCoordinates = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            coordinates = nil
        } else {
            coordinates = try container.decode([[[Double]]].self, forKey: .coordinates)
            multiCoordinates = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if type == "MultiPolygon" {
            try container.encode(multiCoordinates, forKey: .coordinates)
        } else {
            try container.encode(coordinates, forKey: .coordinates)
        }
    }
}

public struct GeoJSONLoader {
    public static func load(from data: Data) throws -> GeoJSONFeatureCollection {
        try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
    }

    public static func resourceURL(
        mainResourceURL: URL?,
        mainBundleURL: URL,
        moduleBundle: Bundle?
    ) -> URL? {
        let bundleName = "TimeZoner_TimeZonerLib.bundle"
        let candidates: [Bundle?] = [
            mainResourceURL
                .map { $0.appendingPathComponent(bundleName) }
                .flatMap(Bundle.init(url:)),
            Bundle(url: mainBundleURL.appendingPathComponent(bundleName)),
            moduleBundle
        ]

        for bundle in candidates.compactMap({ $0 }) {
            if let url = bundle.url(forResource: "timezone-boundaries", withExtension: "json") {
                return url
            }
        }
        return nil
    }

    private static func resourceURL() -> URL? {
        if let url = resourceURL(
            mainResourceURL: Bundle.main.resourceURL,
            mainBundleURL: Bundle.main.bundleURL,
            moduleBundle: nil
        ) {
            return url
        }

        return Bundle.module.url(forResource: "timezone-boundaries", withExtension: "json")
    }

    public static func loadFromBundle() -> GeoJSONFeatureCollection? {
        guard let url = resourceURL(),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
    }
}
