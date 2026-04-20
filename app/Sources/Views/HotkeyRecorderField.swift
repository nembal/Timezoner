import AppKit
import Carbon.HIToolbox
import SwiftUI

public struct HotkeyRecorderField: NSViewRepresentable {
    @Binding var shortcut: SettingsStore.Shortcut?
    public var onCapture: ((SettingsStore.Shortcut?) -> Void)?

    public init(shortcut: Binding<SettingsStore.Shortcut?>,
                onCapture: ((SettingsStore.Shortcut?) -> Void)? = nil) {
        self._shortcut = shortcut
        self.onCapture = onCapture
    }

    public func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onCapture = { new in
            shortcut = new
            onCapture?(new)
        }
        view.render(shortcut)
        return view
    }

    public func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.render(shortcut)
    }

    public final class RecorderView: NSView {
        var onCapture: ((SettingsStore.Shortcut?) -> Void)?
        private let label = NSTextField(labelWithString: "")
        private var capturing = false {
            didSet { needsDisplay = true; refreshLabel() }
        }
        private var current: SettingsStore.Shortcut?

        public override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.cornerRadius = 6
            layer?.borderWidth = 1
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.alignment = .center
            addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.centerYAnchor.constraint(equalTo: centerYAnchor),
                heightAnchor.constraint(equalToConstant: 28),
                widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            ])
            applyColors()
        }

        public required init?(coder: NSCoder) { fatalError() }

        public override var acceptsFirstResponder: Bool { true }
        public override var canBecomeKeyView: Bool { true }

        public override func mouseDown(with event: NSEvent) {
            if !capturing {
                window?.makeFirstResponder(self)
                capturing = true
            }
        }

        public override func becomeFirstResponder() -> Bool {
            capturing = true
            return super.becomeFirstResponder()
        }

        public override func resignFirstResponder() -> Bool {
            capturing = false
            return super.resignFirstResponder()
        }

        public override func keyDown(with event: NSEvent) {
            guard capturing else { super.keyDown(with: event); return }

            if event.keyCode == kVK_Escape {
                window?.makeFirstResponder(nil)
                return
            }

            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let carbonMods = HotkeyEncoding.carbonModifiers(from: mods)

            guard carbonMods != 0 else { NSSound.beep(); return }

            let keyCode = UInt32(event.keyCode)
            let display = HotkeyEncoding.display(keyCode: keyCode, carbonModifiers: carbonMods)
            let shortcut = SettingsStore.Shortcut(keyCode: keyCode, modifiers: carbonMods, display: display)
            onCapture?(shortcut)
            window?.makeFirstResponder(nil)
        }

        public override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            applyColors()
        }

        func render(_ shortcut: SettingsStore.Shortcut?) {
            current = shortcut
            refreshLabel()
        }

        private func refreshLabel() {
            if capturing {
                label.stringValue = "Type shortcut…"
                label.textColor = .secondaryLabelColor
            } else if let current {
                label.stringValue = current.display
                label.textColor = .labelColor
            } else {
                label.stringValue = "Not set"
                label.textColor = .tertiaryLabelColor
            }
            applyColors()
        }

        private func applyColors() {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = (capturing ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
        }
    }
}
