import SwiftUI

public struct ContentView: View {
    @State private var timeState = TimeState()
    @State private var zoneStore = ZoneStore()
    @State private var editingZoneId: UUID? = nil

    public init() {}

    private var idealWidth: CGFloat {
        let cardWidth: CGFloat = 155
        let diffLabelWidth: CGFloat = 36
        let padding: CGFloat = 40
        let count = CGFloat(max(zoneStore.zones.count, 2))
        let diffs = max(count - 1, 0) * diffLabelWidth
        return count * cardWidth + diffs + padding
    }

    private var isTimeAdjusted: Bool {
        abs(timeState.referenceDate.timeIntervalSinceNow) > 60
    }

    public var body: some View {
        VStack(spacing: 14) {
            // Chat field + Now button
            HStack(spacing: 8) {
                ChatField(timeState: timeState, zoneStore: zoneStore)

                if isTimeAdjusted {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            timeState.referenceDate = Date()
                        }
                    }) {
                        Text("Now")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Theme.cardBg, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.5))
                            .shadow(color: Theme.shadow, radius: 1, y: 1)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }

            // Zone cards with time difference annotations
            ZoneCardRow(zones: zoneStore.zones, timeState: timeState, editingZoneId: $editingZoneId, onRemove: { id in
                withAnimation(.easeInOut(duration: 0.3)) {
                    zoneStore.remove(id: id)
                }
            }, onMove: { source, destination in
                zoneStore.move(from: source, to: destination)
            })
        }
        .padding(20)
        .frame(width: idealWidth)
        .fixedSize(horizontal: true, vertical: true)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: zoneStore.zones.count)
        .animation(.easeInOut(duration: 0.25), value: isTimeAdjusted)
        .onKeyPress(.escape) {
            NSApp.keyWindow?.orderOut(nil)
            return .handled
        }
        .background {
            Button("") {
                NotificationCenter.default.post(name: .focusChatField, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
            .hidden()
        }
        .onChange(of: zoneStore.zones.count) {
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
