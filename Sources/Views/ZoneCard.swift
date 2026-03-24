import SwiftUI

public struct ZoneCard: View {
    public let zone: ZoneInfo
    @Bindable public var timeState: TimeState
    public let isSource: Bool
    @Binding public var editingZoneId: UUID?
    public let isDragging: Bool
    public let onRemove: () -> Void
    public let onDragChanged: (CGFloat) -> Void
    public let onDragEnded: () -> Void

    @State private var editText = ""
    @State private var isHovering = false
    @FocusState private var editFieldFocused: Bool

    private var isEditing: Bool {
        editingZoneId == zone.id
    }

    public init(zone: ZoneInfo, timeState: TimeState, isSource: Bool, editingZoneId: Binding<UUID?>,
                isDragging: Bool = false,
                onRemove: @escaping () -> Void,
                onDragChanged: @escaping (CGFloat) -> Void = { _ in },
                onDragEnded: @escaping () -> Void = {}) {
        self.zone = zone
        self.timeState = timeState
        self.isSource = isSource
        self._editingZoneId = editingZoneId
        self.isDragging = isDragging
        self.onRemove = onRemove
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }

    public var body: some View {
        let tz = zone.timeZone
        let date = timeState.referenceDate

        VStack(spacing: 4) {
            // Drag pill — visible on hover
            ZStack {
                if isHovering && !isEditing {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.border)
                        .frame(width: 28, height: 4)
                        .transition(.opacity)
                }
            }
            .frame(height: 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        onDragChanged(value.translation.width)
                    }
                    .onEnded { _ in
                        onDragEnded()
                    }
            )
            .cursor(isHovering && !isEditing ? .openHand : .arrow)

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
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .frame(minWidth: 130, maxWidth: .infinity)
        .background(isEditing ? Theme.accent.opacity(0.04) : Theme.cardBg,
                     in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isEditing ? Theme.accent.opacity(0.5) : (isSource ? Theme.accent.opacity(0.3) : Theme.border),
                              lineWidth: isEditing ? 1.5 : 0.5)
        )
        .shadow(color: isDragging ? Theme.shadow.opacity(2) : Theme.shadow, radius: isDragging ? 8 : 2, y: isDragging ? 4 : 1)
        .scaleEffect(isDragging ? 1.03 : 1.0)
        .overlay(alignment: .topTrailing) {
            if isHovering && !isEditing && !isDragging {
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

    private func liveUpdate(_ text: String) {
        guard let (hour, minute) = InputParser.parseBareTime(text) else { return }
        timeState.setTime(hour: hour, minute: minute, in: zone.timeZone)
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
