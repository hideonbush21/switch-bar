import AppKit
import SwitchBarCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let registry = ToggleRegistry()

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
            popover.performClose(nil)
            return
        }

        guard let button = statusItem.button else { return }
        registry.refreshAll()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func popoverWillShow(_ notification: Notification) {
        registry.refreshAll()
    }
}
