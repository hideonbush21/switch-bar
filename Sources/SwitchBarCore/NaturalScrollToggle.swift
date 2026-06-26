import Combine
import CoreGraphics
import Foundation

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int

@_silgen_name("CGSSetSwipeScrollDirection")
private func CGSSetSwipeScrollDirection(_ connection: Int, _ natural: Bool) -> Int32

public final class NaturalScrollToggle: ToggleProvider {
    public let id = "naturalScroll"
    public let title = "自然滚动"
    public let iconName = "arrow.up.arrow.down"
    @Published public var isOn: Bool = false

    private let shell: ShellRunning
    private let setDirection: (Bool) -> Bool

    public init(
        shell: ShellRunning = ShellHelper(),
        setDirection: @escaping (Bool) -> Bool = NaturalScrollToggle.cgsSetDirection
    ) {
        self.shell = shell
        self.setDirection = setDirection
    }

    public func apply(newValue: Bool) -> Bool {
        guard setDirection(newValue) else { return false }
        let prefValue = newValue ? 2 : 1
        _ = try? shell.run("defaults -currentHost write NSGlobalDomain com.apple.trackpad.scrollBehavior -int \(prefValue)")
        return true
    }

    public func refreshState() {
        do {
            let output = try shell.run("defaults -currentHost read NSGlobalDomain com.apple.trackpad.scrollBehavior")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            isOn = output == "2"
        } catch {
            isOn = true
        }
    }

    public static func cgsSetDirection(_ natural: Bool) -> Bool {
        let conn = CGSMainConnectionID()
        guard conn != 0 else { return false }
        _ = CGSSetSwipeScrollDirection(conn, natural)
        return true
    }
}
