import AppKit
import SwiftUI

struct SearchFieldView: NSViewRepresentable {
    @Binding var text: String
    let onMoveSelection: (Int) -> Void
    let onSubmit: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = FocusSearchField()
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: 16, weight: .regular)
        field.placeholderString = "Search live Kalshi markets"
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
        field.onKeyPress = { keyCode in
            switch keyCode {
            case 125:
                onMoveSelection(1)
            case 126:
                onMoveSelection(-1)
            case 36:
                onSubmit()
            default:
                break
            }
        }
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.font = .systemFont(ofSize: 16, weight: .regular)
        DispatchQueue.main.async {
            guard nsView.window?.firstResponder !== nsView.currentEditor() else { return }
            nsView.window?.makeFirstResponder(nsView)
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
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

private final class FocusSearchField: NSSearchField {
    var onKeyPress: ((UInt16) -> Void)?

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

    override func keyDown(with event: NSEvent) {
        onKeyPress?(event.keyCode)
        if [125, 126].contains(event.keyCode) {
            return
        }
        super.keyDown(with: event)
    }
}
