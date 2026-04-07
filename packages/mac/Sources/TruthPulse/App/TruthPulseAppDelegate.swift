import AppKit
import Combine
import CoreSpotlight
import SwiftUI
import TruthPulseCore

@MainActor
final class TruthPulseAppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var state: AppState?
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private let statusMenu = NSMenu()
    private var cancellables = Set<AnyCancellable>()
    private let hotkeyManager = HotkeyManager()
    private var recorderController: HotkeyRecorderWindowController?
    private let updater = AutoUpdater()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[TruthPulse] applicationDidFinishLaunching")
        do {
            let service = try SearchService()
            let state = AppState(service: service)
            self.state = state
            configurePopover(with: state)
            configureStatusItem()
            registerHotkey()
            observeState(state)
            Task { await updater.checkSilently() }
        } catch {
            fatalError("Failed to initialize TruthPulse: \(error)")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        togglePopover(nil)
        return false
    }

    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let url = URL(string: identifier) else {
            return false
        }
        NSWorkspace.shared.open(url)
        return true
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }

        button.image = makeStatusImage()
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        let hotkeyItem = NSMenuItem(title: "Set Shortcut (\(HotkeyStorage.load().displayString))", action: #selector(showHotkeyRecorder), keyEquivalent: "")
        hotkeyItem.target = self

        let quitItem = NSMenuItem(title: "Quit TruthPulse", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self

        let feedbackItem = NSMenuItem(title: "Provide feedback/report bugs", action: #selector(openFeedback), keyEquivalent: "")
        feedbackItem.target = self

        let updateItem = NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdatesAction), keyEquivalent: "")
        updateItem.target = self

        let spotlightItem = NSMenuItem(title: "Spotlight: not indexed yet", action: nil, keyEquivalent: "")
        spotlightItem.isEnabled = false
        spotlightItem.tag = 999

        let syncItem = NSMenuItem(title: "Sync Interval", action: nil, keyEquivalent: "")
        let syncSubmenu = NSMenu()
        for interval in SyncInterval.allCases {
            let mi = NSMenuItem(title: interval.label, action: #selector(changeSyncInterval(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = interval.rawValue
            mi.state = interval == SyncInterval.load() ? .on : .off
            syncSubmenu.addItem(mi)
        }
        syncItem.submenu = syncSubmenu

        statusMenu.autoenablesItems = false
        statusMenu.items = [hotkeyItem, syncItem, feedbackItem, updateItem, .separator(), spotlightItem, .separator(), quitItem]
    }

    private func configurePopover(with state: AppState) {
        let hostingController = NSHostingController(rootView: QuickSearchView(state: state))
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = hostingController
        applyPopoverSize(for: state.panelMetrics)
    }

    private func observeState(_ state: AppState) {
        Publishers.CombineLatest3(
            state.$results.map { _ in () }.eraseToAnyPublisher(),
            state.$query.map { _ in () }.eraseToAnyPublisher(),
            state.$errorMessage.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(16), scheduler: RunLoop.main)
        .sink { [weak self, weak state] _ in
            guard let self, let state else { return }
            self.applyPopoverSize(for: state.panelMetrics)
        }
        .store(in: &cancellables)

        state.$spotlightIndexedCount
            .combineLatest(state.$spotlightLastIndexed)
            .receive(on: RunLoop.main)
            .sink { [weak self] count, date in
                self?.updateSpotlightMenuItem(count: count, lastIndexed: date)
            }
            .store(in: &cancellables)
    }

    private func updateSpotlightMenuItem(count: Int, lastIndexed: Date?) {
        NSLog("[TruthPulse] updateSpotlightMenuItem called: count=%d, date=%@", count, lastIndexed.map { "\($0)" } ?? "nil")
        guard let item = statusMenu.item(withTag: 999) else {
            NSLog("[TruthPulse] Could not find menu item with tag 999")
            return
        }
        if count == 0 {
            item.title = "Spotlight: not indexed yet"
        } else if let date = lastIndexed {
            let ago = Formatters.relativeString(for: date, relativeTo: Date())
            item.title = "Spotlight: \(count.formatted()) markets indexed, \(ago)"
        } else {
            item.title = "Spotlight: \(count.formatted()) markets indexed"
        }
    }

    // MARK: - Global Hotkey

    private func registerHotkey() {
        let hotkey = HotkeyStorage.load()
        hotkeyManager.register(hotkey) { [weak self] in
            self?.togglePopover(nil)
        }
    }

    @objc
    private func showHotkeyRecorder() {
        if popover.isShown {
            popover.performClose(nil)
        }
        let current = HotkeyStorage.load()
        recorderController = HotkeyRecorderWindowController(current: current) { [weak self] newHotkey in
            HotkeyStorage.save(newHotkey)
            self?.registerHotkey()
            self?.updateHotkeyMenuItem()
        }
        NSApp.activate(ignoringOtherApps: true)
        recorderController?.showWindow(nil)
        recorderController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc
    private func changeSyncInterval(_ sender: NSMenuItem) {
        guard let interval = SyncInterval(rawValue: sender.tag) else { return }
        SyncInterval.save(interval)
        state?.syncInterval = interval
        // Update checkmarks
        if let submenu = sender.menu {
            for item in submenu.items {
                item.state = item.tag == sender.tag ? .on : .off
            }
        }
    }

    private func updateHotkeyMenuItem() {
        if let item = statusMenu.items.first {
            item.title = "Set Shortcut (\(HotkeyStorage.load().displayString))"
        }
    }

    // MARK: - Popover

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            if popover.isShown {
                popover.performClose(sender)
            }
            statusItem?.menu = statusMenu
            button.performClick(nil)
            statusItem?.menu = nil
            return
        }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        if let state {
            state.onPopoverOpen()
            applyPopoverSize(for: state.panelMetrics)
        }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
    }

    @objc
    private func openFeedback() {
        if let url = URL(string: "https://mail.google.com/mail/?view=cm&to=truthpulse@kylesamani.com&su=TruthPulse%20Feedback") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc
    private func checkForUpdatesAction() {
        Task { await updater.checkManually() }
    }

    @objc
    private func quitApp(_ sender: Any?) {
        updater.installPendingUpdateIfNeeded()
        NSApp.terminate(nil)
    }

    private func applyPopoverSize(for metrics: SearchPanelMetrics) {
        popover.contentSize = NSSize(width: metrics.width, height: metrics.height)
    }

    func popoverWillShow(_ notification: Notification) {
        statusItem?.button?.highlight(true)
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem?.button?.highlight(false)
    }

    private func makeStatusImage() -> NSImage {
        let size = NSSize(width: 20, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()

        let path = NSBezierPath()
        path.move(to: CGPoint(x: 1, y: 8))
        path.line(to: CGPoint(x: 6, y: 8))
        path.line(to: CGPoint(x: 8.5, y: 3))
        path.line(to: CGPoint(x: 11.8, y: 13))
        path.line(to: CGPoint(x: 14.6, y: 6))
        path.line(to: CGPoint(x: 19, y: 6))
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = 2.4

        NSColor.labelColor.setStroke()
        path.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
