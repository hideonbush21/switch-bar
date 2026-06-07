import Combine
import Foundation

public final class ScreenSaverToggle: ToggleProvider {
    public let id = "screenSaver"
    public let title = "启动屏保"
    public let iconName = "display"
    public let controlType: ControlType = .action
    @Published public var isOn: Bool = false

    private let shell: ShellRunning

    public init(shell: ShellRunning = ShellHelper()) {
        self.shell = shell
    }

    public func apply(newValue: Bool) -> Bool {
        do {
            _ = try shell.run("open -a ScreenSaverEngine")
            return true
        } catch {
            return false
        }
    }

    public func refreshState() {
        isOn = false
    }
}
