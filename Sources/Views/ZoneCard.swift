import SwiftUI

public struct ZoneCard: View {
    public let zone: ZoneInfo
    public let timeState: TimeState
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
        let currentDate = timeState.referenceDate
        let tz = zone.timeZone

        VStack(spacing: 6) {
            // Zone label
            Text(zone.label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Time display / edit
            if isEditing {
                TextField("HH:mm", text: $editText)
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .frame(width: 120)
                    .focused($editFieldFocused)
                    .onSubmit {
                        commitEdit()
                    }
                    .onExitCommand {
                        isEditing = false
                    }
            } else {
                Text(TimeFormatter.formatTime(currentDate, in: tz))
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: currentDate)
                    .onTapGesture {
                        editText = TimeFormatter.formatTimeEditable(currentDate, in: tz)
                        isEditing = true
                        editFieldFocused = true
                    }
            }

            // Date
            Text(TimeFormatter.formatDate(currentDate, in: tz))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)

            // Relative offset from source zone
            Text(TimeFormatter.relativeOffset(
                from: TimeZone(identifier: timeState.sourceZoneId) ?? .current,
                to: tz,
                at: currentDate
            ))
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(minWidth: 150)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSource ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
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

        // Try parsing HH:mm (24h) or h:mm a (12h)
        let parts: [String]
        if text.contains(":") {
            parts = text.components(separatedBy: ":")
        } else {
            // No colon — not valid for now
            return
        }

        guard parts.count == 2 else { return }

        let hourStr = parts[0].trimmingCharacters(in: .whitespaces)
        var minutePart = parts[1].trimmingCharacters(in: .whitespaces).lowercased()

        // Check for am/pm suffix
        var isPM = false
        var isAM = false
        if minutePart.hasSuffix("pm") {
            isPM = true
            minutePart = String(minutePart.dropLast(2)).trimmingCharacters(in: .whitespaces)
        } else if minutePart.hasSuffix("am") {
            isAM = true
            minutePart = String(minutePart.dropLast(2)).trimmingCharacters(in: .whitespaces)
        } else if minutePart.hasSuffix("p") {
            isPM = true
            minutePart = String(minutePart.dropLast(1)).trimmingCharacters(in: .whitespaces)
        } else if minutePart.hasSuffix("a") {
            isAM = true
            minutePart = String(minutePart.dropLast(1)).trimmingCharacters(in: .whitespaces)
        }

        guard var hour = Int(hourStr), let minute = Int(minutePart) else { return }
        guard minute >= 0, minute <= 59 else { return }

        if isPM && hour < 12 { hour += 12 }
        if isAM && hour == 12 { hour = 0 }
        guard hour >= 0, hour <= 23 else { return }

        timeState.setTime(hour: hour, minute: minute, in: zone.timeZone)
    }
}
