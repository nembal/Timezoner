import SwiftUI

public struct ChatField: View {
    public let timeState: TimeState
    public let zoneStore: ZoneStore
    @Binding public var editingZoneId: UUID?
    @Binding public var highlightedZoneIds: Set<UUID>

    @State private var inputText = ""
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isFocused: Bool

    public init(timeState: TimeState, zoneStore: ZoneStore, editingZoneId: Binding<UUID?>, highlightedZoneIds: Binding<Set<UUID>>) {
        self.timeState = timeState
        self.zoneStore = zoneStore
        self._editingZoneId = editingZoneId
        self._highlightedZoneIds = highlightedZoneIds
    }

    /// The active zone: whatever was last edited, or the first zone as default
    private var activeZone: ZoneInfo? {
        // If a zone matches the current sourceZoneId, use that
        if let match = zoneStore.zones.first(where: { $0.timeZoneId == timeState.sourceZoneId }) {
            return match
        }
        // Otherwise default to first zone
        return zoneStore.zones.first
    }

    public var body: some View {
        TextField(placeholderText, text: $inputText)
            .font(.system(size: 15, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isFocused ? Theme.accent : Theme.border, lineWidth: isFocused ? 2 : 1)
            )
            .focused($isFocused)
            .offset(x: shakeOffset)
            .onAppear {
                // Delay focus to ensure window is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NSApp.activate(ignoringOtherApps: true)
                    isFocused = true
                }
            }
            .onSubmit {
                handleSubmit()
            }
            .onReceive(NotificationCenter.default.publisher(for: .focusChatField)) { _ in
                isFocused = true
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    editingZoneId = nil
                }
            }
    }

    private var placeholderText: String {
        if let zone = activeZone {
            return "11:30 → \(zone.label), or 11:30am SF, +Tokyo..."
        }
        return "11:30am SF, +Tokyo, -NYC..."
    }

    private func handleSubmit() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        // First try the full parser (time + zone, add, remove)
        if let result = InputParser.parse(text) {
            switch result {
            case .timeConversion(let hour, let minute, let zone):
                ensureZoneExists(zone, label: nil)
                timeState.setTime(hour: hour, minute: minute, in: zone)
                highlightZones(matching: [zone])
                inputText = ""
                return

            case .timeInContext(let hour, let minute, let sourceZone, let sourceLabel, let targetZone, let targetLabel):
                ensureZoneExists(sourceZone, label: sourceLabel)
                ensureZoneExists(targetZone, label: targetLabel)
                timeState.setTime(hour: hour, minute: minute, in: sourceZone)
                highlightZones(matching: [sourceZone, targetZone])
                inputText = ""
                return

            case .addZone(let label, let zone):
                withAnimation(.easeInOut(duration: 0.3)) {
                    zoneStore.add(label: label, timezoneId: zone.identifier)
                }
                inputText = ""
                return

            case .removeZone(let label):
                if let match = zoneStore.zones.first(where: {
                    $0.label.caseInsensitiveCompare(label) == .orderedSame
                }) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        zoneStore.remove(id: match.id)
                    }
                    inputText = ""
                    return
                } else if let targetTZ = resolveTimezone(label),
                          let match = zoneStore.zones.first(where: { $0.timeZoneId == targetTZ.identifier }) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        zoneStore.remove(id: match.id)
                    }
                    inputText = ""
                    return
                }
            }
        }

        // If full parser failed, try as bare time → apply to active zone
        if let zone = activeZone, let (hour, minute) = InputParser.parseBareTime(text) {
            timeState.setTime(hour: hour, minute: minute, in: zone.timeZone)
            highlightZones(matching: [zone.timeZone])
            inputText = ""
            return
        }

        triggerShake()
    }

    /// Highlight cards matching the given timezones, auto-clear after a delay
    private func highlightZones(matching zones: [TimeZone]) {
        let ids = Set(zones.compactMap { tz in
            zoneStore.zones.first(where: { $0.timeZoneId == tz.identifier })?.id
        })
        withAnimation(.easeInOut(duration: 0.2)) {
            highlightedZoneIds = ids
        }
        // Clear after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 0.5)) {
                highlightedZoneIds = []
            }
        }
    }

    /// Adds the zone to the store if it's not already present
    private func ensureZoneExists(_ zone: TimeZone, label: String?) {
        let alreadyExists = zoneStore.zones.contains(where: { $0.timeZoneId == zone.identifier })
        if !alreadyExists {
            let displayLabel = label ?? zone.identifier.components(separatedBy: "/").last ?? zone.identifier
            withAnimation(.easeInOut(duration: 0.3)) {
                zoneStore.add(label: displayLabel.capitalized, timezoneId: zone.identifier)
            }
        }
    }

    private func triggerShake() {
        withAnimation(.default) { shakeOffset = 10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.default) { shakeOffset = -10 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.default) { shakeOffset = 0 }
        }
    }
}
