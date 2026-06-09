import Combine
import Foundation

public final class TrueToneToggle: ToggleProvider {
    public let id = "trueTone"
    public let title = "原彩显示"
    public let iconName = "sun.max.fill"
    @Published public var isOn: Bool = false

    private let client: TrueToneClient

    public init(client: TrueToneClient = CoreBrightnessTrueToneClient()) {
        self.client = client
    }

    public func apply(newValue: Bool) -> Bool {
        guard client.isSupported else { return false }
        return client.setEnabled(newValue)
    }

    public func refreshState() {
        isOn = client.isSupported && client.isEnabled
    }
}
