import SwiftUI

public struct ZoneCard: View {
    public let zone: ZoneInfo
    @Bindable public var timeState: TimeState
    public let isSource: Bool
    @Binding public var editingZoneId: UUID?
    public let canMoveLeft: Bool
    public let canMoveRight: Bool
    public let onRemove: () -> Void
    public let onMoveLeft: () -> Void
    public let onMoveRight: () -> Void

    @State private var editText = ""
    @State private var isHovering = false
    @FocusState private var editFieldFocused: Bool

    private var isEditing: Bool {
        editingZoneId == zone.id
    }

    public init(zone: ZoneInfo, timeState: TimeState, isSource: Bool, editingZoneId: Binding<UUID?>,
                canMoveLeft: Bool = false, canMoveRight: Bool = false,
                onRemove: @escaping () -> Void,
                onMoveLeft: @escaping () -> Void = {},
                onMoveRight: @escaping () -> Void = {}) {
        self.zone = zone
        self.timeState = timeState
        self.isSource = isSource
        self._editingZoneId = editingZoneId
        self.canMoveLeft = canMoveLeft
        self.canMoveRight = canMoveRight
        self.onRemove = onRemove
        self.onMoveLeft = onMoveLeft
        self.onMoveRight = onMoveRight
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
                TextField("time", text: $editText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .frame(width: 120)
                    .focused($editFieldFocused)
                    .onSubmit { editingZoneId = nil }
                    .onExitCommand { editingZoneId = nil }
                    .onChange(of: editText) { _, newValue in
                        liveUpdate(newValue)
                    }
            } else {
                Text(displayTime)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                    .onTapGesture {
                        editText = ""
                        editingZoneId = zone.id
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
        .background(isEditing ? Theme.accent.opacity(0.04) : Theme.cardBg,
                     in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isEditing ? Theme.accent.opacity(0.5) : (isSource ? Theme.accent.opacity(0.3) : Theme.border),
                              lineWidth: isEditing ? 1.5 : 0.5)
        )
        .shadow(color: Theme.shadow, radius: 2, y: 1)
        // Hover controls: move arrows + remove
        .overlay(alignment: .topTrailing) {
            if isHovering && !isEditing {
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
        .overlay(alignment: .leading) {
            if isHovering && !isEditing && canMoveLeft {
                Button(action: onMoveLeft) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(4)
                        .background(Theme.background, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.border, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .offset(x: -6)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .trailing) {
            if isHovering && !isEditing && canMoveRight {
                Button(action: onMoveRight) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(4)
                        .background(Theme.background, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.border, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .offset(x: 6)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private func liveUpdate(_ text: String) {
        guard let (hour, minute) = parseFlexibleTime(text) else { return }
        timeState.setTime(hour: hour, minute: minute, in: zone.timeZone)
    }

    private func parseFlexibleTime(_ raw: String) -> (hour: Int, minute: Int)? {
        let text = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { return nil }

        var stripped = text
        var isPM = false
        var isAM = false
        for suffix in ["p.m.", "pm", "p"] {
            if stripped.hasSuffix(suffix) {
                isPM = true
                stripped = String(stripped.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        if !isPM {
            for suffix in ["a.m.", "am", "a"] {
                if stripped.hasSuffix(suffix) {
                    isAM = true
                    stripped = String(stripped.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }

        var hour: Int
        var minute: Int

        if stripped.contains(":") {
            let parts = stripped.components(separatedBy: ":")
            guard let h = Int(parts[0].trimmingCharacters(in: .whitespaces)) else { return nil }
            hour = h
            let minStr = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            minute = Int(minStr) ?? 0
        } else if let num = Int(stripped) {
            if num >= 0 && num <= 24 {
                hour = num == 24 ? 0 : num
                minute = 0
            } else if num >= 100 && num <= 2359 {
                hour = num / 100
                minute = num % 100
            } else {
                return nil
            }
        } else {
            return nil
        }

        if isPM && hour < 12 { hour += 12 }
        if isAM && hour == 12 { hour = 0 }

        guard hour >= 0, hour <= 23, minute >= 0, minute <= 59 else { return nil }
        return (hour, minute)
    }
}
