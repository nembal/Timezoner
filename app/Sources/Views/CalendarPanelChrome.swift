import SwiftUI

public struct CalendarPanelChrome<Header: View, Content: View>: View {
    let isHugging: Bool
    let isFocused: Bool
    let contentOpacity: Double
    let contentOffset: CGFloat
    let interactionEnabled: Bool
    let header: Header
    let content: Content

    public init(
        isHugging: Bool,
        isFocused: Bool,
        contentOpacity: Double = 1,
        contentOffset: CGFloat = 0,
        interactionEnabled: Bool = true,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.isHugging = isHugging
        self.isFocused = isFocused
        self.contentOpacity = contentOpacity
        self.contentOffset = contentOffset
        self.interactionEnabled = interactionEnabled
        self.header = header()
        self.content = content()
    }

    public var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: isHugging ? 0 : CalendarPanelMetrics.cornerRadius,
            bottomLeadingRadius: CalendarPanelMetrics.cornerRadius,
            bottomTrailingRadius: CalendarPanelMetrics.cornerRadius,
            topTrailingRadius: isHugging ? 0 : CalendarPanelMetrics.cornerRadius,
            style: .continuous
        )

        VStack(spacing: 0) {
            DragHandle(showPill: true, isHugging: isHugging)
                .allowsHitTesting(interactionEnabled)

            VStack(spacing: CalendarPanelMetrics.contentGap) {
                header.frame(height: CalendarPanelMetrics.navHeight)
                content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .opacity(contentOpacity)
            .offset(x: contentOffset)
            .allowsHitTesting(interactionEnabled)
            .accessibilityHidden(!interactionEnabled)
            .padding(.horizontal, CalendarPanelMetrics.horizontalInset)
            .padding(.top, CalendarPanelMetrics.topInset)
            .padding(.bottom, CalendarPanelMetrics.bottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                isFocused ? Theme.accent.opacity(0.22) : Theme.border,
                lineWidth: 1
            )
        )
    }
}

public struct CalendarToolbarIcon: View {
    let systemName: String
    let label: String
    let hint: String
    let action: () -> Void

    public init(systemName: String, label: String, hint: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.label = label
        self.hint = hint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: CalendarPanelMetrics.iconTarget, height: CalendarPanelMetrics.iconTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textSecondary)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .help(label)
    }
}
