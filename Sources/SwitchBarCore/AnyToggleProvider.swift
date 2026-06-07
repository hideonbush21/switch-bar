import Combine
import Foundation

public final class AnyToggleProvider: Identifiable, ObservableObject {
    public let id: String
    public let title: String
    public let iconName: String
    public let controlType: ControlType

    @Published public private(set) var isOn: Bool
    @Published public private(set) var isBusy: Bool = false
    @Published public private(set) var errorMessage: String?

    public var subtitle: String? {
        _subtitle()
    }

    private let _subtitle: () -> String?
    private let _setIsOn: (Bool) -> Void
    private let _apply: (Bool) -> Bool
    private let _refresh: () -> Void
    private let _readIsOn: () -> Bool
    private let providerObject: AnyObject

    public init<T: ToggleProvider>(_ provider: T) where T.ID == String {
        self.id = provider.id
        self.title = provider.title
        self.iconName = provider.iconName
        self.controlType = provider.controlType
        self.isOn = provider.isOn
        self.providerObject = provider
        self._subtitle = { provider.subtitle }
        self._setIsOn = { provider.isOn = $0 }
        self._apply = { provider.apply(newValue: $0) }
        self._refresh = { provider.refreshState() }
        self._readIsOn = { provider.isOn }
    }

    public func requestSet(_ newValue: Bool) {
        guard controlType == .toggle else { return }
        guard !isBusy else { return }

        let oldValue = isOn
        isBusy = true
        errorMessage = nil

        let success = _apply(newValue)
        if success {
            _setIsOn(newValue)
            isOn = newValue
        } else {
            _setIsOn(oldValue)
            errorMessage = "操作失败，请稍后重试"
            _refresh()
            isOn = _readIsOn()
        }

        isBusy = false
    }

    public func triggerAction() {
        guard controlType == .action else { return }
        guard !isBusy else { return }

        isBusy = true
        errorMessage = nil

        let success = _apply(true)
        if !success {
            errorMessage = "操作失败，请稍后重试"
        }

        _setIsOn(false)
        isOn = false
        isBusy = false
    }

    public func refreshState() {
        guard !isBusy else { return }

        _refresh()
        if controlType == .action {
            _setIsOn(false)
            isOn = false
        } else {
            isOn = _readIsOn()
        }
    }
}
