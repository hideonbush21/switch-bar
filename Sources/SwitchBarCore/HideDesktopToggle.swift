import Combine
import Foundation

public final class HideDesktopToggle: ToggleProvider {
    public let id = "hideDesktop"
    public let title = "隐藏桌面图标"
    public let iconName = "desktopcomputer"
    @Published public var isOn: Bool = false

    private let service: FinderDesktopIconService

    public init(service: FinderDesktopIconService = FinderDesktopIconService()) {
        self.service = service
    }

    public func apply(newValue: Bool) -> Bool {
        service.setDesktopIconsHidden(newValue)
    }

    public func refreshState() {
        isOn = service.areDesktopIconsHidden()
    }
}
