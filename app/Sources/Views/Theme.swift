import SwiftUI
import AppKit

public enum Theme {
    // Terracotta accent — same in both modes
    public static let accent = Color(red: 0.85, green: 0.47, blue: 0.34) // #D97757

    // Adaptive colors — light/dark
    public static let background = Color(light: .init(red: 0.98, green: 0.975, blue: 0.96),
                                          dark: .init(red: 0.11, green: 0.11, blue: 0.10))
    public static let cardBg = Color(light: .white,
                                      dark: .init(red: 0.17, green: 0.17, blue: 0.16))
    public static let border = Color(light: .init(red: 0.88, green: 0.87, blue: 0.85),
                                      dark: .init(red: 0.30, green: 0.29, blue: 0.28))
    public static let textPrimary = Color(light: .init(red: 0.13, green: 0.13, blue: 0.12),
                                           dark: .init(red: 0.93, green: 0.92, blue: 0.90))
    public static let textSecondary = Color(light: .init(red: 0.45, green: 0.44, blue: 0.42),
                                             dark: .init(red: 0.68, green: 0.66, blue: 0.64))
    public static let textTertiary = Color(light: .init(red: 0.65, green: 0.63, blue: 0.60),
                                            dark: .init(red: 0.50, green: 0.48, blue: 0.46))
    public static let shadow = Color(light: Color.black.opacity(0.06),
                                      dark: Color.black.opacity(0.3))
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
