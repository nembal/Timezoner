import SwiftUI

public struct ZoneCard: View {
    public enum AccessibilityAction {
        case editTime
        case remove
        case moveEarlier
        case moveLater
    }

    public let zone: ZoneInfo
    public let referenceMoment: ReferenceMomentController
    public let isSource: Bool
    public let isHighlighted: Bool
    @Binding public var editingZoneId: UUID?
    public let isDragging: Bool
    public let canMoveEarlier: Bool
    public let canMoveLater: Bool
    public let onRemove: () -> Void
    public let onMoveEarlier: () -> Void
    public let onMoveLater: () -> Void
    public let onDragChanged: (CGSize) -> Void
    public let onDragEnded: () -> Void

    @State private var editText = ""
    @State private var isHovering = false
    @FocusState private var editFieldFocused: Bool

    private var timeState: TimeState {
        referenceMoment.timeState
    }

    private var isEditing: Bool {
        editingZoneId == zone.id
    }

    private var isProminent: Bool {
        isEditing || isHighlighted
    }

    public init(zone: ZoneInfo, referenceMoment: ReferenceMomentController, isSource: Bool, isHighlighted: Bool = false,
                editingZoneId: Binding<UUID?>,
                isDragging: Bool = false,
                canMoveEarlier: Bool = false,
                canMoveLater: Bool = false,
                onRemove: @escaping () -> Void,
                onMoveEarlier: @escaping () -> Void = {},
                onMoveLater: @escaping () -> Void = {},
                onDragChanged: @escaping (CGSize) -> Void = { _ in },
                onDragEnded: @escaping () -> Void = {}) {
        self.zone = zone
        self.referenceMoment = referenceMoment
        self.isSource = isSource
        self.isHighlighted = isHighlighted
        self._editingZoneId = editingZoneId
        self.isDragging = isDragging
        self.canMoveEarlier = canMoveEarlier
        self.canMoveLater = canMoveLater
        self.onRemove = onRemove
        self.onMoveEarlier = onMoveEarlier
        self.onMoveLater = onMoveLater
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
                        onDragChanged(value.translation)
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
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                Text(TimeFormatter.gmtOffset(for: tz, at: date))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: true, vertical: false)

                cardActions
            }

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
                Button {
                    performAccessibilityAction(.editTime)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(TimeFormatter.formatTimeDigits(date, in: tz))
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .contentTransition(.numericText())

                        Text(TimeFormatter.formatAmPm(date, in: tz))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit time in \(zone.label)")
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
        .background(isProminent ? Theme.accent.opacity(0.06) : Theme.cardBg,
                     in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isProminent ? Theme.accent : (isSource ? Theme.accent.opacity(0.3) : Theme.border),
                              lineWidth: isProminent ? 2 : 1)
        )
        .shadow(color: Theme.shadow, radius: isDragging ? 8 : 3, y: isDragging ? 4 : 2)
        .scaleEffect(isDragging ? 1.03 : 1.0)
        .overlay(alignment: .topTrailing) {
            if isHovering && !isEditing && !isDragging {
                Button(action: { performAccessibilityAction(.remove) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(4)
                        .background(Theme.background, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(zone.label)")
                .padding(6)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(zone.label), \(TimeFormatter.formatTime(date, in: tz)), \(TimeFormatter.formatDate(date, in: tz)), \(TimeFormatter.gmtOffset(for: tz, at: date))")
        .accessibilityActions {
            Button("Edit time") { performAccessibilityAction(.editTime) }
            Button("Remove city") { performAccessibilityAction(.remove) }
            if canMoveEarlier {
                Button("Move earlier") { performAccessibilityAction(.moveEarlier) }
            }
            if canMoveLater {
                Button("Move later") { performAccessibilityAction(.moveLater) }
            }
        }
    }

    private var cardActions: some View {
        Menu {
            Button("Edit time") { performAccessibilityAction(.editTime) }
            Button("Remove city") { performAccessibilityAction(.remove) }
            Divider()
            Button("Move earlier") { performAccessibilityAction(.moveEarlier) }
                .disabled(!canMoveEarlier)
            Button("Move later") { performAccessibilityAction(.moveLater) }
                .disabled(!canMoveLater)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 20, height: 20)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Actions for \(zone.label)")
        .help("Edit, remove, or move \(zone.label)")
    }

    public func performAccessibilityAction(_ action: AccessibilityAction) {
        switch action {
        case .editTime:
            editText = ""
            editingZoneId = zone.id
            editFieldFocused = true
        case .remove:
            onRemove()
        case .moveEarlier:
            if canMoveEarlier { onMoveEarlier() }
        case .moveLater:
            if canMoveLater { onMoveLater() }
        }
    }

    private func liveUpdate(_ text: String) {
        guard let (hour, minute) = InputParser.parseBareTime(text) else { return }
        referenceMoment.setTime(hour: hour, minute: minute, in: zone.timeZone)
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
