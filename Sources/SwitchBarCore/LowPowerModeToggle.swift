import Combine
import Foundation

public final class LowPowerModeToggle: ToggleProvider {
    public let id = "lowPowerMode"
    public let title = "低电量模式"
    public let iconName = "battery.25"
    @Published public var isOn: Bool = false

    private let shell: ShellRunning

    public init(shell: ShellRunning = ShellHelper()) {
        self.shell = shell
    }

    public func apply(newValue: Bool) -> Bool {
        let value = newValue ? "1" : "0"

        // 快速路径：sudoers 规则已存在，免密执行
        if let _ = try? shell.run("sudo -n /usr/bin/pmset -a lowpowermode \(value)") {
            return true
        }

        // 首次：弹密码框，同时执行命令 + 安装 sudoers 规则（后续免密）
        do {
            _ = try shell.run(installAndApplyCommand(value: value))
            return true
        } catch {
            return false
        }
    }

    private func installAndApplyCommand(value: String) -> String {
        let user = NSUserName()
        let rule = "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a lowpowermode 0, /usr/bin/pmset -a lowpowermode 1"
        // 写临时脚本避免 osascript 嵌套引号问题
        let scriptPath = NSTemporaryDirectory() + "switchbar-pmset-setup.sh"
        let script = """
            #!/bin/sh
            /usr/bin/pmset -a lowpowermode \(value)
            echo '\(rule)' > /etc/sudoers.d/switchbar-pmset
            chmod 0440 /etc/sudoers.d/switchbar-pmset
            """
        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        return "osascript -e 'do shell script \"sh \(scriptPath)\" with administrator privileges'"
    }

    public func refreshState() {
        do {
            let output = try shell.run("pmset -g | grep lowpowermode | awk '{print $2}'")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            isOn = output == "1"
        } catch {
            isOn = false
        }
    }
}
