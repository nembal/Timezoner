import SwiftUI

public struct HelpPopover: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How to use")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                helpSection("Set a time", examples: [
                    "11:30am SF",
                    "3pm bangkok",
                    "15:00 BKK",
                    "noon NYC",
                ])

                helpSection("Compare zones", examples: [
                    "1130am BKK in SF",
                    "3pm london in tokyo",
                ])

                helpSection("Just a time (uses active zone)", examples: [
                    "11:30",
                    "3pm",
                    "15",
                ])

                helpSection("Add / remove zones", examples: [
                    "+Tokyo",
                    "add Hong Kong",
                    "-SF",
                    "remove NYC",
                ])
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                tipRow("Click a card's time to edit it live")
                tipRow("Drag the pill on a card to reorder")
                tipRow("Hover a card for the remove button")
                tipRow("Drag the top bar to move the window")
                tipRow("Press Esc to dismiss the window")
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func helpSection(_ title: String, examples: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)

            ForEach(examples, id: \.self) { example in
                Text(example)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("·")
                .foregroundStyle(Theme.textTertiary)
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
