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
                Text(TimeFormatter.formatTime(currentDate, in: tz))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
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
        // Scroll wheel to shift time in 30-min increments
        .onScrollGesture { delta in
            let increment = delta > 0 ? 30 : -30
            let calendar = Calendar.current
            if let newDate = calendar.date(byAdding: .minute, value: increment, to: timeState.referenceDate) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    timeState.referenceDate = newDate
                }
            }
        }
    }

    private func commitEdit() {
        defer { isEditing = false }

        let text = editText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let parts: [String]
        if text.contains(":") {
            parts = text.components(separatedBy: ":")
        } else {
            return
        }

        guard parts.count == 2 else { return }

        let hourStr = parts[0].trimmingCharacters(in: .whitespaces)
        var minutePart = parts[1].trimmingCharacters(in: .whitespaces).lowercased()

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

// MARK: - Scroll gesture helper

extension View {
    func onScrollGesture(action: @escaping (CGFloat) -> Void) -> some View {
        self.background(ScrollGestureView(action: action))
    }
}

private struct ScrollGestureView: NSViewRepresentable {
    let action: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollCaptureView {
        let view = ScrollCaptureView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: ScrollCaptureView, context: Context) {
        nsView.action = action
    }
}

class ScrollCaptureView: NSView {
    var action: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        if abs(event.deltaY) > 0.5 {
            action?(event.deltaY)
        }
    }
}
