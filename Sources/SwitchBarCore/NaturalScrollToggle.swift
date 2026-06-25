import Combine
import Foundation

public final class NaturalScrollToggle: ToggleProvider {
    public let id = "naturalScroll"
    public let title = "自然滚动"
    public let iconName = "arrow.up.arrow.down"
    @Published public var isOn: Bool = false

    private let shell: ShellRunning
    private static let key = "com.apple.trackpad.scrollBehavior"
    private static let naturalValue = 2
    private static let traditionalValue = 1

    public init(shell: ShellRunning = ShellHelper()) {
        self.shell = shell
    }

    public func apply(newValue: Bool) -> Bool {
        let intValue = newValue ? Self.naturalValue : Self.traditionalValue
        do {
            _ = try shell.run("defaults -currentHost write NSGlobalDomain \(Self.key) -int \(intValue)")
            return true
        } catch {
            return false
        }
    }

    public func refreshState() {
        do {
            let output = try shell.run("defaults -currentHost read NSGlobalDomain \(Self.key)")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            isOn = output == "\(Self.naturalValue)"
        } catch {
            isOn = true
        }
    }
}
