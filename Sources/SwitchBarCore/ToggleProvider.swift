import Combine

public enum ControlType {
    case toggle
    case action
}

public protocol ToggleProvider: Identifiable, ObservableObject {
    var id: String { get }
    var title: String { get }
    var subtitle: String? { get }
    var iconName: String { get }
    var controlType: ControlType { get }
    var isOn: Bool { get set }

    func apply(newValue: Bool) -> Bool
    func refreshState()
}

public extension ToggleProvider {
    var controlType: ControlType { .toggle }
    var subtitle: String? { nil }
}
