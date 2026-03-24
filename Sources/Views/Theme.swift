import SwiftUI

public enum Theme {
    // Claude UI palette — solid, warm, clean
    public static let background = Color(red: 0.98, green: 0.975, blue: 0.96)    // #FAF9F5 warm off-white
    public static let cardBg = Color.white
    public static let accent = Color(red: 0.85, green: 0.47, blue: 0.34)          // #D97757 terracotta
    public static let accentSubtle = Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.1)
    public static let border = Color(red: 0.88, green: 0.87, blue: 0.85)          // subtle warm gray
    public static let textPrimary = Color(red: 0.13, green: 0.13, blue: 0.12)     // near-black warm
    public static let textSecondary = Color(red: 0.45, green: 0.44, blue: 0.42)   // warm gray
    public static let textTertiary = Color(red: 0.65, green: 0.63, blue: 0.60)    // lighter warm gray
    public static let shadow = Color.black.opacity(0.06)

    // Day period colors for timeline
    public static let night = Color(red: 0.22, green: 0.24, blue: 0.30).opacity(0.15)
    public static let morning = Color(red: 0.95, green: 0.88, blue: 0.68).opacity(0.30)
    public static let workHours = Color(red: 0.82, green: 0.92, blue: 0.78).opacity(0.35)
    public static let evening = Color(red: 0.95, green: 0.84, blue: 0.66).opacity(0.30)
}
