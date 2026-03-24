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
        let date = timeState.referenceDate

        VStack(spacing: 6) {
            // City name + GMT offset
            HStack(spacing: 5) {
                Text(zone.label)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                Text(TimeFormatter.gmtOffset(for: tz, at: date))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            .lineLimit(1)

            // Time: big digits + smaller am/pm
            if isEditing {
                TextField("time", text: $editText)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
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
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(TimeFormatter.formatTimeDigits(date, in: tz))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())

                    Text(TimeFormatter.formatAmPm(date, in: tz))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                .onTapGesture {
                    editText = ""
                    editingZoneId = zone.id
                    editFieldFocused = true
                }
            }

            // Date
            Text(TimeFormatter.formatDate(date, in: tz))
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .frame(minWidth: 130, maxWidth: .infinity)
        .background(isEditing ? Theme.accent.opacity(0.04) : Theme.cardBg,
                     in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isEditing ? Theme.accent.opacity(0.5) : (isSource ? Theme.accent.opacity(0.3) : Theme.border),
                              lineWidth: isEditing ? 1.5 : 0.5)
        )
        .shadow(color: Theme.shadow, radius: 2, y: 1)
        // Hover controls
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
        guard let (hour, minute) = InputParser.parseBareTime(text) else { return }
        timeState.setTime(hour: hour, minute: minute, in: zone.timeZone)
    }
}
