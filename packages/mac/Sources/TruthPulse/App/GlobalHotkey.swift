import AppKit
import Carbon

struct Hotkey: Codable, Equatable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        var carbon: UInt32 = 0
        if modifiers.contains(.command) { carbon |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbon |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbon |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbon |= UInt32(shiftKey) }
        self.carbonModifiers = carbon
    }

    var displayString: String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    private static func keyName(for code: UInt32) -> String {
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 36: "Return", 48: "Tab",
            51: "Delete", 53: "Esc", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            105: "F13", 107: "F14", 113: "F15", 118: "F4", 120: "F2",
            122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return map[code] ?? "Key\(code)"
    }
}

@MainActor
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    // Static reference so the C callback can reach us
    fileprivate static var current: HotkeyManager?

    func register(_ hotkey: Hotkey, action: @escaping () -> Void) {
        unregister()
        self.action = action
        Self.current = self

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyCallback,
            1,
            &eventType,
            nil,
            &handlerRef
        )

        let hotkeyID = EventHotKeyID(signature: 0x5450_5368, id: 1) // 'TPSh'
        RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.carbonModifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = handlerRef {
            RemoveEventHandler(ref)
            handlerRef = nil
        }
        action = nil
    }

    fileprivate func fireAction() {
        action?()
    }
}

private func hotkeyCallback(
    _: EventHandlerCallRef?,
    _: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        HotkeyManager.current?.fireAction()
    }
    return noErr
}

// MARK: - Storage

enum HotkeyStorage {
    private static let key = "TruthPulse.GlobalHotkey"

    static var defaultHotkey: Hotkey {
        // Cmd+Shift+K
        Hotkey(keyCode: 40, modifiers: [.command, .shift])
    }

    static func load() -> Hotkey {
        guard let data = UserDefaults.standard.data(forKey: key),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return defaultHotkey
        }
        return hotkey
    }

    static func save(_ hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Recorder Window

@MainActor
final class HotkeyRecorderWindowController: NSWindowController {
    private let label = NSTextField(labelWithString: "Press your desired shortcut...")
    private let currentLabel = NSTextField(labelWithString: "")
    private var localMonitor: Any?
    private var captured: Hotkey?
    private let onSave: (Hotkey) -> Void

    init(current: Hotkey, onSave: @escaping (Hotkey) -> Void) {
        self.onSave = onSave

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Set Global Shortcut"
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.center()

        super.init(window: panel)

        let container = NSView(frame: panel.contentView!.bounds)
        container.autoresizingMask = [.width, .height]

        currentLabel.stringValue = "Current: \(current.displayString)"
        currentLabel.font = .systemFont(ofSize: 13, weight: .medium)
        currentLabel.alignment = .center
        currentLabel.frame = NSRect(x: 20, y: 110, width: 280, height: 20)
        container.addSubview(currentLabel)

        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.alignment = .center
        label.frame = NSRect(x: 20, y: 75, width: 280, height: 24)
        container.addSubview(label)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: 170, y: 16, width: 80, height: 32)
        container.addSubview(saveButton)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.frame = NSRect(x: 80, y: 16, width: 80, height: 32)
        container.addSubview(cancelButton)

        panel.contentView = container
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
            return nil // swallow the event
        }
    }

    private func handleKey(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !mods.isEmpty else { return } // require at least one modifier
        let hotkey = Hotkey(keyCode: UInt32(event.keyCode), modifiers: mods)
        captured = hotkey
        label.stringValue = hotkey.displayString
    }

    @objc private func save() {
        if let captured {
            onSave(captured)
        }
        cleanup()
    }

    @objc private func cancel() {
        cleanup()
    }

    private func cleanup() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        close()
    }
}
