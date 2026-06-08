import Combine
import Foundation

public final class EmptyTrashToggle: ToggleProvider {
    public let id = "emptyTrash"
    public let title = "清空废纸篓"
    public let iconName = "trash.fill"
    public let controlType: ControlType = .action
    @Published public var isOn: Bool = false

    private let shell: ShellRunning

    public init(shell: ShellRunning = ShellHelper()) {
        self.shell = shell
    }

    public func apply(newValue: Bool) -> Bool {
        do {
            _ = try shell.run("osascript -e 'tell application \"Finder\" to empty the trash'")
            return true
        } catch {
            return false
        }
    }

    public func refreshState() {
        isOn = false
    }
}
