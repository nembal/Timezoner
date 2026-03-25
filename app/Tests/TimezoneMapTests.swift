import Foundation
import TimeZonerLib

private func expectTrue(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition { testsPassed += 1 }
    else { testsFailed += 1; print("  FAIL [line \(line)] \(label)") }
}

func runTimezoneMapTests() {
    print("Running TimezoneMapTests...")

    // ── GeoJSON Parsing ──────────────────────────────────────────────

    // Polygon
    let polygonJSON = """
    {"type":"FeatureCollection","features":[{"type":"Feature","properties":{"tzid":"America/New_York"},"geometry":{"type":"Polygon","coordinates":[[[-74,40],[-74,41],[-73,41],[-73,40],[-74,40]]]}}]}
    """.data(using: .utf8)!
    let polygonFC = try! JSONDecoder().decode(GeoJSONFeatureCollection.self, from: polygonJSON)
    expectTrue(polygonFC.features.count == 1, "polygon: feature count == 1")
    expectTrue(polygonFC.features[0].properties.tzid == "America/New_York", "polygon: tzid match")
    expectTrue(polygonFC.features[0].polygons.count == 1, "polygon: polygons accessor == 1")

    // MultiPolygon
    let multiJSON = """
    {"type":"FeatureCollection","features":[{"type":"Feature","properties":{"tzid":"Pacific/Auckland"},"geometry":{"type":"MultiPolygon","coordinates":[[[[-74,40],[-74,41],[-73,41],[-73,40],[-74,40]]],[[[170,-36],[170,-37],[171,-37],[171,-36],[170,-36]]]]}}]}
    """.data(using: .utf8)!
    let multiFC = try! JSONDecoder().decode(GeoJSONFeatureCollection.self, from: multiJSON)
    expectTrue(multiFC.features[0].polygons.count == 2, "multipolygon: polygons accessor == 2")

    // Empty features
    let emptyJSON = """
    {"type":"FeatureCollection","features":[]}
    """.data(using: .utf8)!
    let emptyFC = try! JSONDecoder().decode(GeoJSONFeatureCollection.self, from: emptyJSON)
    expectTrue(emptyFC.features.count == 0, "empty: feature count == 0")

    // Coordinate order: first element is longitude
    let coords = polygonFC.features[0].polygons[0][0]
    expectTrue(coords[0] == -74.0, "coordinate order: first element is longitude")
    expectTrue(coords[1] == 40.0, "coordinate order: second element is latitude")

    // ── Bundle Loading ───────────────────────────────────────────────

    if let bundled = GeoJSONLoader.loadFromBundle() {
        expectTrue(bundled.features.count > 400, "bundle: has 400+ features")
        expectTrue(bundled.features.allSatisfy({ !$0.properties.tzid.isEmpty }), "bundle: all features have tzid")
        let bangkok = bundled.features.first { $0.properties.tzid == "Asia/Bangkok" }
        expectTrue(bangkok != nil, "bundle: contains Asia/Bangkok")
    } else {
        testsFailed += 3
        print("  FAIL: GeoJSONLoader.loadFromBundle() returned nil")
    }

    // ── Projection ───────────────────────────────────────────────────

    let proj = MapProjection(size: CGSize(width: 360, height: 140))

    let topLeft = proj.project(longitude: -180, latitude: 70)
    expectTrue(abs(topLeft.x) < 0.01 && abs(topLeft.y) < 0.01, "projection: (-180,70) -> top-left")

    let bottomRight = proj.project(longitude: 180, latitude: -70)
    expectTrue(abs(bottomRight.x - 360) < 0.01 && abs(bottomRight.y - 140) < 0.01, "projection: (180,-70) -> bottom-right")

    let center = proj.project(longitude: 0, latitude: 0)
    expectTrue(abs(center.x - 180) < 0.01 && abs(center.y - 70) < 0.01, "projection: (0,0) -> center")

    let clamped = proj.project(longitude: 0, latitude: -90)
    expectTrue(abs(clamped.y - 140) < 0.01, "projection: lat -90 clamped to -70 -> bottom")

    let ring: [[Double]] = [[-74, 40], [-74, 41], [-73, 41], [-73, 40], [-74, 40]]
    let path = proj.pathForRing(ring)
    expectTrue(!path.boundingBox.isNull, "pathForRing: produces non-null bounding box")

    // ── City Coordinates ─────────────────────────────────────────────

    let bkk = CityCoordinates.lookup("Asia/Bangkok")
    expectTrue(bkk != nil, "city: Bangkok lookup exists")
    if let bkk = bkk {
        expectTrue(bkk.latitude > 13 && bkk.latitude < 14, "city: Bangkok lat ~13.7")
        expectTrue(bkk.longitude > 100 && bkk.longitude < 101, "city: Bangkok lon ~100.5")
    }

    let la = CityCoordinates.lookup("America/Los_Angeles")
    expectTrue(la != nil, "city: LA lookup exists")

    expectTrue(CityCoordinates.lookup("Invalid/Zone") == nil, "city: invalid returns nil")

    for iana in ["Asia/Bangkok", "America/Los_Angeles", "America/New_York", "Europe/Paris"] {
        expectTrue(CityCoordinates.lookup(iana) != nil, "city: default zone \(iana) has coords")
    }

    // ── Band Coloring Logic ──────────────────────────────────────────

    let now = Date()

    // Pre-compute offset lookup for test timezones
    let testTzids = ["America/New_York", "Asia/Bangkok", "Europe/London",
                     "America/Toronto", "America/Los_Angeles", "Asia/Ho_Chi_Minh"]
    var testLookup: [String: Int] = [:]
    for tzid in testTzids {
        if let tz = TimeZone(identifier: tzid) {
            testLookup[tzid] = tz.secondsFromGMT(for: now)
        }
    }

    let nyOffsets = MapColorLogic.offsetSeconds(for: ["America/New_York"], at: now)

    let hlState = MapColorLogic.visualState(
        for: "America/New_York",
        userZoneIds: ["Asia/Bangkok"], highlightedZoneIds: ["America/New_York"],
        highlightedOffsetSeconds: nyOffsets, userOffsetSeconds: [],
        offsetLookup: testLookup)
    expectTrue(hlState == .highlighted, "color: highlighted takes priority")

    let userState = MapColorLogic.visualState(
        for: "Asia/Bangkok",
        userZoneIds: ["Asia/Bangkok"], highlightedZoneIds: [],
        highlightedOffsetSeconds: [], userOffsetSeconds: [],
        offsetLookup: testLookup)
    expectTrue(userState == .userZone, "color: user zone recognized")

    let bothState = MapColorLogic.visualState(
        for: "Asia/Bangkok",
        userZoneIds: ["Asia/Bangkok"], highlightedZoneIds: ["Asia/Bangkok"],
        highlightedOffsetSeconds: [], userOffsetSeconds: [],
        offsetLookup: testLookup)
    expectTrue(bothState == .highlighted, "color: highlighted beats userZone")

    let gmtState = MapColorLogic.visualState(
        for: "Europe/London",
        userZoneIds: [], highlightedZoneIds: [],
        highlightedOffsetSeconds: [], userOffsetSeconds: [],
        offsetLookup: testLookup)
    expectTrue(gmtState == .defaultLand, "color: London returns default land")

    // Highlight band: Toronto shares UTC offset with NY
    let torontoBandState = MapColorLogic.visualState(
        for: "America/Toronto",
        userZoneIds: [], highlightedZoneIds: ["America/New_York"],
        highlightedOffsetSeconds: nyOffsets, userOffsetSeconds: [],
        offsetLookup: testLookup)
    expectTrue(torontoBandState == .highlightBand, "color: Toronto highlight-band when NY highlighted")

    // Highlight band: LA does NOT share offset with NY
    let laBandState = MapColorLogic.visualState(
        for: "America/Los_Angeles",
        userZoneIds: [], highlightedZoneIds: ["America/New_York"],
        highlightedOffsetSeconds: nyOffsets, userOffsetSeconds: [],
        offsetLookup: testLookup)
    expectTrue(laBandState != .highlightBand, "color: LA not highlight-band when NY highlighted")

    // User band: zones sharing offset with a user zone get userBand
    let bkkOffsets = MapColorLogic.offsetSeconds(for: ["Asia/Bangkok"], at: now)
    let userBandState = MapColorLogic.visualState(
        for: "Asia/Ho_Chi_Minh",
        userZoneIds: ["Asia/Bangkok"], highlightedZoneIds: [],
        highlightedOffsetSeconds: [], userOffsetSeconds: bkkOffsets,
        offsetLookup: testLookup)
    expectTrue(userBandState == .userBand, "color: Ho Chi Minh in Bangkok's user band")

    let nyOffset = MapColorLogic.utcOffsetHour(for: "America/New_York", at: now)
    expectTrue(nyOffset == -5 || nyOffset == -4, "offset: NY is -5 or -4 (DST)")

    let indiaOffset = MapColorLogic.utcOffsetHour(for: "Asia/Kolkata", at: now)
    expectTrue(indiaOffset == 5, "offset: India is 5 (floor of 5.5)")

    // Negative half-hour: Newfoundland UTC-3:30 → floor(-3.5) = -4
    let nfldOffset = MapColorLogic.utcOffsetHour(for: "America/St_Johns", at: now)
    expectTrue(nfldOffset == -4 || nfldOffset == -3, "offset: Newfoundland is -4 or -3 (DST)")

    // ── Integration ──────────────────────────────────────────────────

    if let bundled = GeoJSONLoader.loadFromBundle() {
        let intProj = MapProjection(size: CGSize(width: 750, height: 250))
        var allValid = true
        for feature in bundled.features {
            for ring2 in feature.polygons {
                for coord2 in ring2 {
                    guard coord2.count >= 2 else { allValid = false; continue }
                    let pt = intProj.project(longitude: coord2[0], latitude: coord2[1])
                    if pt.x.isNaN || pt.y.isNaN || pt.x.isInfinite || pt.y.isInfinite {
                        allValid = false
                    }
                }
            }
        }
        expectTrue(allValid, "integration: all projected coordinates are valid")
    }

    let mapProj = MapProjection(size: CGSize(width: 750, height: 250))
    for iana in ["Asia/Bangkok", "America/Los_Angeles", "America/New_York", "Europe/Paris"] {
        if let coord3 = CityCoordinates.lookup(iana) {
            let pt = mapProj.project(longitude: coord3.longitude, latitude: coord3.latitude)
            let inBounds = pt.x >= 0 && pt.x <= 750 && pt.y >= 0 && pt.y <= 250
            expectTrue(inBounds, "integration: \(iana) city dot within map bounds")
        }
    }
}
