import Combine
import Foundation

public final class ShowHiddenFilesToggle: ToggleProvider {
    public let id = "showHiddenFiles"
    public let title = "显示隐藏文件"
    public let iconName = "eye.fill"
    @Published public var isOn: Bool = false

    private let service: FinderHiddenFilesService

    public init(service: FinderHiddenFilesService = FinderHiddenFilesService()) {
        self.service = service
    }

    public func apply(newValue: Bool) -> Bool {
        service.setHiddenFilesVisible(newValue)
    }

    public func refreshState() {
        isOn = service.areHiddenFilesVisible()
    }
}
