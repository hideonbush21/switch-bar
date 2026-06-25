import AppKit
import SwitchBarCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let registry = ToggleRegistry()
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerToggles()
        configureStatusItem()
        configurePopover()
    }

    private func registerToggles() {
        registry.register(AnyToggleProvider(DarkModeToggle()))
        registry.register(AnyToggleProvider(KeepAwakeToggle()))
        registry.register(AnyToggleProvider(HideDesktopToggle()))
        registry.register(AnyToggleProvider(ScreenSaverToggle()))
        registry.register(AnyToggleProvider(ShowHiddenFilesToggle()))
        registry.register(AnyToggleProvider(EmptyTrashToggle()))
        registry.register(AnyToggleProvider(TrueToneToggle()))
        registry.register(AnyToggleProvider(LowPowerModeToggle()))
        registry.loadState()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        if #available(macOS 11.0, *) {
            button.image = NSImage(
                systemSymbolName: "switch.2",
                accessibilityDescription: "SwitchBar"
            )
        } else {
            button.title = "SB"
        }
        button.image?.isTemplate = true
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 320, height: 360)
        popover.contentViewController = NSHostingController(rootView: PopoverView(registry: registry))
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
            return
        }

        guard let button = statusItem.button else { return }
        registry.refreshAll()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        installEventMonitors()
    }

    private func closePopover() {
        popover.performClose(nil)
        removeEventMonitors()
    }

    private func installEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return event }
            if let contentView = self.popover.contentViewController?.view,
               contentView.window != event.window {
                self.closePopover()
            }
            return event
        }
    }

    private func removeEventMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    func popoverWillShow(_ notification: Notification) {
        registry.refreshAll()
    }

    func popoverDidClose(_ notification: Notification) {
        removeEventMonitors()
    }
}
