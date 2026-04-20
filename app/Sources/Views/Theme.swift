import SwiftUI
import AppKit

public enum Theme {
    // Terracotta accent — same in both modes
    public static let accent = Color(red: 0.85, green: 0.47, blue: 0.34) // #D97757
    // Cool counter-accent for hover states — slate blue, distinct from terracotta
    public static let hover = Color(red: 0.32, green: 0.52, blue: 0.75) // #527FBF

    // Adaptive colors — light/dark
    public static let background = Color(light: .init(red: 0.96, green: 0.95, blue: 0.93),
                                          dark: .init(red: 0.11, green: 0.11, blue: 0.10))
    public static let cardBg = Color(light: .init(red: 0.995, green: 0.99, blue: 0.98),
                                      dark: .init(red: 0.17, green: 0.17, blue: 0.16))
    public static let border = Color(light: .init(red: 0.80, green: 0.77, blue: 0.72),
                                      dark: .init(red: 0.30, green: 0.29, blue: 0.28))
    public static let textPrimary = Color(light: .init(red: 0.10, green: 0.10, blue: 0.08),
                                           dark: .init(red: 0.93, green: 0.92, blue: 0.90))
    public static let textSecondary = Color(light: .init(red: 0.38, green: 0.35, blue: 0.31),
                                             dark: .init(red: 0.68, green: 0.66, blue: 0.64))
    public static let textTertiary = Color(light: .init(red: 0.55, green: 0.51, blue: 0.46),
                                            dark: .init(red: 0.50, green: 0.48, blue: 0.46))
    public static let shadow = Color(light: Color.black.opacity(0.08),
                                      dark: Color.black.opacity(0.3))

    // Map — land sits noticeably below background so zones pop
    public static let mapLand = Color(light: .init(red: 0.76, green: 0.73, blue: 0.68),
                                       dark: .init(red: 0.22, green: 0.22, blue: 0.20))
    // Shadow-outline painted under colored borders to give polygons depth on both modes
    public static let mapOutline = Color(light: Color.black.opacity(0.25),
                                          dark: Color.white.opacity(0.12))
    // Halo behind city dots — adapts so dots read against both light and dark land
    public static let mapCityHalo = Color(light: Color.white.opacity(0.85),
                                           dark: Color.white.opacity(0.55))
}

// Adaptive Color helper — no asset catalog needed
extension Color {
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        }))
    }
}
