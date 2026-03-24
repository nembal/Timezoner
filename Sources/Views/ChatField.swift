import SwiftUI

public struct ChatField: View {
    public let timeState: TimeState
    public let zoneStore: ZoneStore

    @State private var inputText = ""
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isFocused: Bool

    public init(timeState: TimeState, zoneStore: ZoneStore) {
        self.timeState = timeState
        self.zoneStore = zoneStore
    }

    public var body: some View {
        TextField("11:30am SF, +Tokyo, -NYC...", text: $inputText)
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isFocused ? Theme.accent.opacity(0.4) : Theme.border, lineWidth: isFocused ? 1.5 : 0.5)
            )
            .shadow(color: Theme.shadow, radius: 2, y: 1)
            .focused($isFocused)
            .offset(x: shakeOffset)
            .onAppear {
                isFocused = true
            }
            .onSubmit {
                handleSubmit()
            }
            .onReceive(NotificationCenter.default.publisher(for: .focusChatField)) { _ in
                isFocused = true
            }
    }

    private func handleSubmit() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        guard let result = InputParser.parse(text) else {
            triggerShake()
            return
        }

        switch result {
        case .timeConversion(let hour, let minute, let zone):
            timeState.setTime(hour: hour, minute: minute, in: zone)

        case .addZone(let label, let zone):
            withAnimation(.easeInOut(duration: 0.3)) {
                zoneStore.add(label: label, timezoneId: zone.identifier)
            }

        case .removeZone(let label):
            if let match = zoneStore.zones.first(where: {
                $0.label.caseInsensitiveCompare(label) == .orderedSame
            }) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    zoneStore.remove(id: match.id)
                }
            } else if let targetTZ = resolveTimezone(label),
                      let match = zoneStore.zones.first(where: { $0.timeZoneId == targetTZ.identifier }) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    zoneStore.remove(id: match.id)
                }
            } else {
                triggerShake()
                return
            }
        }

        inputText = ""
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
