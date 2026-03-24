import SwiftUI

public struct ZoneCard: View {
    public let zone: ZoneInfo
    @Bindable public var timeState: TimeState
    public let isSource: Bool
    public let onRemove: () -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @State private var isHovering = false
    @FocusState private var editFieldFocused: Bool

    public init(zone: ZoneInfo, timeState: TimeState, isSource: Bool, onRemove: @escaping () -> Void) {
        self.zone = zone
        self.timeState = timeState
        self.isSource = isSource
        self.onRemove = onRemove
    }

    public var body: some View {
        let tz = zone.timeZone
        let displayTime = TimeFormatter.formatTime(timeState.referenceDate, in: tz)
        let displayDate = TimeFormatter.formatDate(timeState.referenceDate, in: tz)

        VStack(spacing: 4) {
            // Zone label
            Text(zone.label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)

            // Time display / edit
            if isEditing {
                TextField("HH:mm", text: $editText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .frame(width: 110)
                    .focused($editFieldFocused)
                    .onSubmit { commitEdit() }
                    .onExitCommand { isEditing = false }
            } else {
                Text(displayTime)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                    .onTapGesture {
                        editText = TimeFormatter.formatTimeEditable(timeState.referenceDate, in: tz)
                        isEditing = true
                        editFieldFocused = true
                    }
            }

            // Date
            Text(displayDate)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .frame(minWidth: 130, maxWidth: .infinity)
        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSource ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: isSource ? 1.5 : 0.5)
        )
        .shadow(color: Theme.shadow, radius: 2, y: 1)
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(4)
                        .background(Theme.background, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private func commitEdit() {
        defer { isEditing = false }

        let text = editText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        // Try parsing via the full InputParser first (handles "10pm", "3:30 pm", etc.)
        // Prepend the zone label so InputParser can resolve it
        let withZone = text + " " + zone.label
        if let result = InputParser.parse(withZone),
           case .timeConversion(let hour, let minute, _) = result {
            timeState.setTime(hour: hour, minute: minute, in: zone.timeZone)
            return
        }

        // Fallback: simple HH:mm or H:mm parsing
        guard text.contains(":") else { return }
        let parts = text.components(separatedBy: ":")
        guard parts.count == 2 else { return }

        let hourStr = parts[0].trimmingCharacters(in: .whitespaces)
        var minutePart = parts[1].trimmingCharacters(in: .whitespaces).lowercased()

        var isPM = false
        var isAM = false
        for suffix in ["p.m.", "pm", "p"] {
            if minutePart.hasSuffix(suffix) {
                isPM = true
                minutePart = String(minutePart.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        if !isPM {
            for suffix in ["a.m.", "am", "a"] {
                if minutePart.hasSuffix(suffix) {
                    isAM = true
                    minutePart = String(minutePart.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }

        guard var hour = Int(hourStr), let minute = Int(minutePart) else { return }
        guard minute >= 0, minute <= 59 else { return }

        if isPM && hour < 12 { hour += 12 }
        if isAM && hour == 12 { hour = 0 }
        guard hour >= 0, hour <= 23 else { return }

        timeState.setTime(hour: hour, minute: minute, in: zone.timeZone)
    }
}
