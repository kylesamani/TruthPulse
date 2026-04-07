import AppKit
import SwiftUI
import TruthPulseCore

struct SearchFieldView: NSViewRepresentable {
    @Binding var text: String
    var isEnabled: Bool = true
    var placeholderText: String = "Search locally cached markets."
    let onMoveSelection: (Int) -> Void
    let onSubmit: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = FocusSearchField()
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: 16, weight: .regular)
        field.placeholderString = placeholderText
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.cell?.usesSingleLineMode = true
        field.sendsWholeSearchString = false
        field.sendsSearchStringImmediately = true
        field.controlSize = .large
        field.wantsLayer = true
        field.layer?.cornerRadius = 14
        field.layer?.borderWidth = 1
        field.layer?.borderColor = NSColor(Color.truthPulseLine).cgColor
        field.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.96).cgColor
        field.coordinator = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.isEnabled = isEnabled
        nsView.placeholderString = placeholderText
        nsView.font = .systemFont(ofSize: 16, weight: .regular)
        nsView.alphaValue = isEnabled ? 1.0 : 0.5
        if isEnabled {
            DispatchQueue.main.async {
                guard nsView.window?.firstResponder !== nsView.currentEditor() else { return }
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchFieldView

        init(_ parent: SearchFieldView) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onMoveSelection(1)
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onMoveSelection(-1)
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

private final class FocusSearchField: NSSearchField {
    weak var coordinator: SearchFieldView.Coordinator?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.borderColor = NSColor(Color.truthPulseLine).cgColor
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.96).cgColor
    }
}
