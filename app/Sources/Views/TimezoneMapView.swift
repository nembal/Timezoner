import SwiftUI

// Preference key to capture Canvas size without side effects
private struct MapSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

public struct TimezoneMapView: View {
    public let zones: [ZoneInfo]
    public let timeState: TimeState
    public let highlightedZoneIds: Set<UUID>
    public var onAddZone: ((String, String) -> Void)?

    @State private var geoData: GeoJSONFeatureCollection?
    @AppStorage("mapExpanded") private var isExpanded = true
    @State private var hoveredTzid: String?
    @State private var hoveredOffset: Int?
    @State private var mapSize: CGSize = .zero
    @State private var cachedPaths: [(tzid: String, paths: [CGPath])] = []

    public init(zones: [ZoneInfo], timeState: TimeState, highlightedZoneIds: Set<UUID>,
                onAddZone: ((String, String) -> Void)? = nil) {
        self.zones = zones
        self.timeState = timeState
        self.highlightedZoneIds = highlightedZoneIds
        self.onAddZone = onAddZone
    }

    private var userIanaIds: Set<String> {
        Set(zones.map(\.timeZoneId))
    }

    private var highlightedIanaIds: Set<String> {
        Set(highlightedZoneIds.compactMap { id in
            zones.first(where: { $0.id == id })?.timeZoneId
        })
    }

    private func gmtLabel(for offsetSeconds: Int) -> String {
        let sign = offsetSeconds >= 0 ? "+" : "-"
        let total = abs(offsetSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if minutes > 0 {
            return "GMT\(sign)\(hours):\(String(format: "%02d", minutes))"
        } else if hours == 0 {
            return "GMT"
        } else {
            return "GMT\(sign)\(hours)"
        }
    }

    private func labelFromIana(_ ianaId: String) -> String {
        let city = ianaId.components(separatedBy: "/").last ?? ianaId
        return city.replacingOccurrences(of: "_", with: " ")
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toggle — full-width hit target
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text("Map")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                    Spacer()
                }
                .contentShape(Rectangle())
                .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .trailing) {
                if let offset = hoveredOffset {
                    Text(gmtLabel(for: offset))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .padding(.vertical, 4)
            .animation(.easeInOut(duration: 0.15), value: hoveredOffset)

            if isExpanded, let geoData = geoData {
                Canvas { context, size in
                    let hlOffsets = MapColorLogic.offsetSeconds(for: highlightedIanaIds, at: timeState.referenceDate)
                    let userOffsets = MapColorLogic.offsetSeconds(for: userIanaIds, at: timeState.referenceDate)
                    let offsetLookup = MapColorLogic.buildOffsetLookup(for: geoData.features, at: timeState.referenceDate)

                    // Use cached paths if available, otherwise build on the fly (first frame)
                    let useCache = !cachedPaths.isEmpty
                    let projection = useCache ? nil : MapProjection(size: size)

                    for i in 0..<geoData.features.count {
                        let tzid = geoData.features[i].properties.tzid

                        let state = MapColorLogic.visualState(
                            for: tzid,
                            userZoneIds: userIanaIds,
                            highlightedZoneIds: highlightedIanaIds,
                            highlightedOffsetSeconds: hlOffsets,
                            userOffsetSeconds: userOffsets,
                            offsetLookup: offsetLookup
                        )

                        let isInHoveredBand: Bool = {
                            guard let hOffset = hoveredOffset else { return false }
                            guard let featureOffset = offsetLookup[tzid] else { return false }
                            return featureOffset == hOffset
                        }()
                        let isHoveredPolygon = (tzid == hoveredTzid)

                        let fill: Color
                        let border: Color
                        let borderWidth: CGFloat
                        let darkOutline: Bool

                        if state == .highlighted {
                            fill = Theme.accent.opacity(0.25)
                            border = Theme.accent
                            borderWidth = 1.5
                            darkOutline = true
                        } else if state == .highlightBand {
                            fill = Theme.accent.opacity(0.25)
                            border = Theme.accent.opacity(0.15)
                            borderWidth = 0.5
                            darkOutline = false
                        } else if state == .userZone {
                            fill = Theme.accent.opacity(0.12)
                            border = Theme.accent.opacity(0.6)
                            borderWidth = 1.5
                            darkOutline = true
                        } else if state == .userBand {
                            fill = Theme.accent.opacity(0.12)
                            border = Theme.accent.opacity(0.08)
                            borderWidth = 0.5
                            darkOutline = false
                        } else if isHoveredPolygon {
                            fill = Theme.textSecondary.opacity(0.15)
                            border = Theme.textSecondary.opacity(0.4)
                            borderWidth = 1.0
                            darkOutline = true
                        } else if isInHoveredBand {
                            fill = Theme.textSecondary.opacity(0.08)
                            border = Theme.border.opacity(0.3)
                            borderWidth = 0.5
                            darkOutline = false
                        } else {
                            fill = Theme.mapLand
                            border = Theme.border.opacity(0.4)
                            borderWidth = 0.5
                            darkOutline = false
                        }

                        // Use cached CGPaths when available, compute only on first frame
                        let featurePaths: [CGPath]
                        if useCache, i < cachedPaths.count {
                            featurePaths = cachedPaths[i].paths
                        } else {
                            featurePaths = projection!.pathsForFeature(geoData.features[i])
                        }

                        for cgPath in featurePaths {
                            let swiftPath = Path(cgPath)
                            context.fill(swiftPath, with: .color(fill))
                            if darkOutline {
                                context.stroke(swiftPath, with: .color(Color.black.opacity(0.25)), lineWidth: borderWidth + 1)
                            }
                            context.stroke(swiftPath, with: .color(border), lineWidth: borderWidth)
                        }
                    }

                    // City dots
                    let dotProjection = projection ?? MapProjection(size: size)
                    for zone in zones {
                        guard let coord = CityCoordinates.lookup(zone.timeZoneId) else { continue }
                        let point = dotProjection.project(longitude: coord.longitude, latitude: coord.latitude)
                        let isHL = highlightedZoneIds.contains(zone.id)
                        let radius: CGFloat = isHL ? 4.5 : 3.5
                        let dotRect = CGRect(x: point.x - radius, y: point.y - radius,
                                             width: radius * 2, height: radius * 2)
                        let outlineRect = CGRect(x: point.x - radius - 1, y: point.y - radius - 1,
                                                 width: (radius + 1) * 2, height: (radius + 1) * 2)
                        context.fill(Path(ellipseIn: outlineRect), with: .color(.white.opacity(0.8)))
                        context.fill(Path(ellipseIn: dotRect), with: .color(Theme.accent))
                        if isHL {
                            let glowRect = CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)
                            context.fill(Path(ellipseIn: glowRect), with: .color(Theme.accent.opacity(0.25)))
                        }
                    }
                }
                .frame(height: 320)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: MapSizeKey.self, value: geo.size)
                    }
                )
                .onPreferenceChange(MapSizeKey.self) { newSize in
                    if mapSize != newSize {
                        mapSize = newSize
                        rebuildPathCache()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        let tzid = hitTest(at: location)
                        hoveredTzid = tzid
                        if let tzid = tzid, let tz = TimeZone(identifier: tzid) {
                            hoveredOffset = tz.secondsFromGMT(for: timeState.referenceDate)
                        } else {
                            hoveredOffset = nil
                        }
                    case .ended:
                        hoveredTzid = nil
                        hoveredOffset = nil
                    }
                }
                .onTapGesture { location in
                    guard let tzid = hitTest(at: location) else { return }
                    guard !userIanaIds.contains(tzid) else { return }
                    let label = labelFromIana(tzid)
                    onAddZone?(label, tzid)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            if geoData == nil {
                geoData = GeoJSONLoader.loadFromBundle()
            }
        }
    }

    // ── Cached hit testing ──

    private func rebuildPathCache() {
        guard let geoData = geoData, mapSize.width > 0 else { return }
        let projection = MapProjection(size: mapSize)
        cachedPaths = geoData.features.map { feature in
            (tzid: feature.properties.tzid, paths: projection.pathsForFeature(feature))
        }
    }

    private func hitTest(at point: CGPoint) -> String? {
        // Use cached paths (no CGPath reconstruction per hover event)
        for entry in cachedPaths.reversed() {
            for path in entry.paths {
                if path.contains(point) {
                    return entry.tzid
                }
            }
        }
        return nil
    }
}
