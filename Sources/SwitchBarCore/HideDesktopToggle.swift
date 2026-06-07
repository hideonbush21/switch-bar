import Combine
import Foundation

public final class HideDesktopToggle: ToggleProvider {
    public let id = "hideDesktop"
    public let title = "隐藏桌面图标"
    public let iconName = "desktopcomputer"
    @Published public var isOn: Bool = false

    private let shell: ShellRunning

    public init(shell: ShellRunning = ShellHelper()) {
        self.shell = shell
    }

    public func apply(newValue: Bool) -> Bool {
        let createDesktopValue = newValue ? "false" : "true"
        let command = "defaults write com.apple.finder CreateDesktop -bool \(createDesktopValue) && killall Finder"

        do {
            _ = try shell.run(command)
            return true
        } catch {
            return false
        }
    }

    public func refreshState() {
        do {
            let output = try shell.run("defaults read com.apple.finder CreateDesktop")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            isOn = output == "0" || output == "false"
        } catch {
            isOn = false
        }
    }
}
