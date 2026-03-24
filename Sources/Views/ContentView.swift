import SwiftUI

public struct ContentView: View {
    @State private var timeState = TimeState()
    @State private var zoneStore = ZoneStore()

    public init() {}

    private var idealWidth: CGFloat {
        let cardWidth: CGFloat = 150
        let spacing: CGFloat = 12
        let padding: CGFloat = 40
        return max(400, CGFloat(zoneStore.zones.count) * (cardWidth + spacing) + padding + 20)
    }

    private var isTimeAdjusted: Bool {
        abs(timeState.referenceDate.timeIntervalSinceNow) > 60
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ChatField(timeState: timeState, zoneStore: zoneStore)

                if isTimeAdjusted {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            timeState.referenceDate = Date()
                        }
                    }) {
                        Text("Now")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.cardBg, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.warmBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }

            ZoneCardRow(zones: zoneStore.zones, timeState: timeState, onRemove: { id in
                withAnimation(.easeInOut(duration: 0.3)) {
                    zoneStore.remove(id: id)
                }
            })

            TimeScrubber(timeState: timeState)
        }
        .padding(20)
        .frame(width: idealWidth)
        .background(.ultraThinMaterial)
        .animation(.easeInOut(duration: 0.25), value: zoneStore.zones.count)
        .animation(.easeInOut(duration: 0.25), value: isTimeAdjusted)
        .onKeyPress(.escape) {
            NSApp.keyWindow?.orderOut(nil)
            return .handled
        }
        .background {
            // Hidden button to capture Cmd+N keyboard shortcut
            Button("") {
                NotificationCenter.default.post(name: .focusChatField, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
            .hidden()
        }
        .onChange(of: zoneStore.zones.count) {
            // Notify the window to resize
            DispatchQueue.main.async {
                if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
                    let frame = window.frame
                    let newWidth = idealWidth
                    let newFrame = NSRect(
                        x: frame.midX - newWidth / 2,
                        y: frame.origin.y,
                        width: newWidth,
                        height: frame.height
                    )
                    window.setFrame(newFrame, display: true, animate: true)
                }
            }
        }
    }
}

extension Notification.Name {
    public static let focusChatField = Notification.Name("focusChatField")
}
