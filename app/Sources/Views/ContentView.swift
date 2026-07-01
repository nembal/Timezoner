import SwiftUI

public struct ContentView: View {
    @State private var timeState = TimeState()
    @State private var zoneStore = ZoneStore()
    @State private var editingZoneId: UUID? = nil
    @State private var showingSettings = false
    @State private var isHuggingMenuBar = true
    @State private var highlightedZoneIds: Set<UUID> = []
    private let settings = SettingsStore.shared

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
        !timeState.isLive
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            DragHandle(showPill: true, isHugging: isHuggingMenuBar)

            VStack(spacing: 14) {
                // Chat field + Now + Help
                HStack(spacing: 8) {
                    ChatField(timeState: timeState, zoneStore: zoneStore, editingZoneId: $editingZoneId, highlightedZoneIds: $highlightedZoneIds)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            timeState.goLive()
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
                                    .strokeBorder(Theme.border, lineWidth: 1)
                            )
                        }
                    .buttonStyle(.plain)

                    Button(action: { showingSettings.toggle() }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15))
                            .foregroundStyle(showingSettings ? Theme.accent : Theme.textTertiary)
                            .rotationEffect(.degrees(showingSettings ? 22 : 0))
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showingSettings)
                        }
                    .buttonStyle(.plain)
                    .help("Settings (⌘,)")
                    .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                        SettingsPopover(settings: settings)
                    }
                }

                // Zone cards with time difference annotations
                ZoneCardRow(zones: zoneStore.zones, timeState: timeState, editingZoneId: $editingZoneId, highlightedZoneIds: highlightedZoneIds, onRemove: { id in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        zoneStore.remove(id: id)
                    }
                }, onMove: { source, destination in
                    zoneStore.move(from: source, to: destination)
                })

                // Timezone map
                TimezoneMapView(
                    zones: zoneStore.zones,
                    timeState: timeState,
                    highlightedZoneIds: highlightedZoneIds,
                    onAddZone: { label, ianaId in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            zoneStore.add(label: label, timezoneId: ianaId)
                        }
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .padding(.top, 6)
        }
        .frame(width: idealWidth)
        .fixedSize(horizontal: true, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture {
            editingZoneId = nil
        }
        .background(Theme.background)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: isHuggingMenuBar ? 0 : 12,
            bottomLeadingRadius: 12,
            bottomTrailingRadius: 12,
            topTrailingRadius: isHuggingMenuBar ? 0 : 12,
            style: .continuous
        ))
        .onAppear {
            ensureDefaultSource()
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelHuggingChanged)) { notification in
            if let hugging = notification.object as? Bool {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHuggingMenuBar = hugging
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .timeZonerDeepLink)) { notification in
            guard let deepLink = notification.object as? TimeZonerDeepLink else { return }
            handleDeepLink(deepLink)
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
        .background {
            Button("") { showingSettings.toggle() }
                .keyboardShortcut(",", modifiers: .command)
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

    private func handleDeepLink(_ deepLink: TimeZonerDeepLink) {
        editingZoneId = nil

        switch deepLink {
        case .open:
            focusChatField()
        case .setTime(let hour, let minute, let zoneID, let label):
            guard let timeZone = TimeZone(identifier: zoneID) else { return }
            ensureZoneExists(zoneID: zoneID, label: label)
            timeState.setTime(hour: hour, minute: minute, in: timeZone)
            highlightZones(matchingZoneID: zoneID)
            focusChatField()
        }
    }

    private func ensureZoneExists(zoneID: String, label: String?) {
        guard !zoneStore.zones.contains(where: { $0.timeZoneId == zoneID }) else { return }
        let fallbackLabel = zoneID.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? zoneID
        withAnimation(.easeInOut(duration: 0.3)) {
            zoneStore.add(label: label ?? fallbackLabel, timezoneId: zoneID)
        }
    }

    private func highlightZones(matchingZoneID zoneID: String) {
        let ids = Set(zoneStore.zones.filter { $0.timeZoneId == zoneID }.map(\.id))
        withAnimation(.easeInOut(duration: 0.2)) {
            highlightedZoneIds = ids
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 0.5)) {
                highlightedZoneIds = []
            }
        }
    }

    private func focusChatField() {
        NotificationCenter.default.post(name: .focusChatField, object: nil)
    }
}

extension Notification.Name {
    public static let focusChatField = Notification.Name("focusChatField")
    public static let panelHuggingChanged = Notification.Name("panelHuggingChanged")
}
