import SwiftUI

public struct ContentView: View {
    @State private var timeState = TimeState()
    @State private var zoneStore = ZoneStore()
    @State private var editingZoneId: UUID? = nil
    @State private var showingHelp = false

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
        VStack(spacing: 0) {
            // Drag handle
            DragHandle(showPill: true)

            VStack(spacing: 14) {
                // Chat field + Now + Help
                HStack(spacing: 8) {
                    ChatField(timeState: timeState, zoneStore: zoneStore, editingZoneId: $editingZoneId)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            timeState.referenceDate = Date()
                            editingZoneId = nil
                        }
                    }) {
                        Text("Now")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(isTimeAdjusted ? Theme.accent : Theme.textTertiary)
                            .padding(.horizontal, 14)
                            .frame(maxHeight: .infinity)
                            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Theme.border, lineWidth: 0.5)
                            )
                        }
                    .buttonStyle(.plain)

                    Button(action: { showingHelp.toggle() }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(showingHelp ? Theme.accent : Theme.textTertiary)
                            .frame(maxHeight: .infinity)
                            .padding(.horizontal, 6)
                            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Theme.border, lineWidth: 0.5)
                            )
                        }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingHelp, arrowEdge: .bottom) {
                        HelpPopover()
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
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 6)
        }
        .frame(width: idealWidth)
        .fixedSize(horizontal: true, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture {
            editingZoneId = nil
        }
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            ensureDefaultSource()
        }
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

    private func ensureDefaultSource() {
        if let first = zoneStore.zones.first,
           !zoneStore.zones.contains(where: { $0.timeZoneId == timeState.sourceZoneId }) {
            timeState.sourceZoneId = first.timeZoneId
        }
    }
}

extension Notification.Name {
    public static let focusChatField = Notification.Name("focusChatField")
}
