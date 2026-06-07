import AppKit
import Combine
import Foundation

public final class DarkModeToggle: ToggleProvider {
    public let id = "darkMode"
    public let title = "深色模式"
    public let iconName = "moon.fill"
    @Published public var isOn: Bool = false

    private let shell: ShellRunning

    public init(shell: ShellRunning = ShellHelper()) {
        self.shell = shell
        refreshState()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(interfaceThemeChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    public func apply(newValue: Bool) -> Bool {
        let value = newValue ? "true" : "false"
        let command = "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to \(value)'"

        do {
            _ = try shell.run(command)
            return true
        } catch {
            return false
        }
    }

    public func refreshState() {
        let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        isOn = match == .darkAqua
    }

    @objc private func interfaceThemeChanged() {
        refreshState()
    }
}
