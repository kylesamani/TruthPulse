import AppKit
import Combine
import SwiftUI

@MainActor
final class TruthPulseAppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var state: AppState?
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private let statusMenu = NSMenu()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let service = try SearchService()
            let state = AppState(service: service)
            self.state = state
            configurePopover(with: state)
            configureStatusItem()
            observeState(state)
            state.start()
        } catch {
            fatalError("Failed to initialize TruthPulse: \(error)")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        togglePopover(nil)
        return false
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

        let quitItem = NSMenuItem(title: "Quit TruthPulse", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.autoenablesItems = false
        statusMenu.items = [quitItem]
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
        state.$results
            .receive(on: RunLoop.main)
            .sink { [weak self, weak state] _ in
                guard let self, let state else { return }
                self.applyPopoverSize(for: state.panelMetrics)
            }
            .store(in: &cancellables)

        state.$query
            .receive(on: RunLoop.main)
            .sink { [weak self, weak state] _ in
                guard let self, let state else { return }
                self.applyPopoverSize(for: state.panelMetrics)
            }
            .store(in: &cancellables)

        state.$errorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self, weak state] _ in
                guard let self, let state else { return }
                self.applyPopoverSize(for: state.panelMetrics)
            }
            .store(in: &cancellables)
    }

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
            state.start()
            applyPopoverSize(for: state.panelMetrics)
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.becomeKey()
    }

    @objc
    private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func applyPopoverSize(for metrics: SearchPanelMetrics) {
        popover.contentSize = NSSize(width: metrics.width, height: metrics.height)
        popover.contentViewController?.view.frame = NSRect(origin: .zero, size: popover.contentSize)
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
