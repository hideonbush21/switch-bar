import Combine
import Foundation

public final class ShowHiddenFilesToggle: ToggleProvider {
    public let id = "showHiddenFiles"
    public let title = "显示隐藏文件"
    public let iconName = "eye.fill"
    @Published public var isOn: Bool = false

    private let shell: ShellRunning

    public init(shell: ShellRunning = ShellHelper()) {
        self.shell = shell
    }

    public func apply(newValue: Bool) -> Bool {
        let value = newValue ? "true" : "false"
        let command = "defaults write com.apple.finder AppleShowAllFiles -bool \(value) && killall Finder"

        do {
            _ = try shell.run(command)
            return true
        } catch {
            return false
        }
    }

    public func refreshState() {
        do {
            let output = try shell.run("defaults read com.apple.finder AppleShowAllFiles")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            isOn = output == "1" || output == "true"
        } catch {
            isOn = false
        }
    }
}
