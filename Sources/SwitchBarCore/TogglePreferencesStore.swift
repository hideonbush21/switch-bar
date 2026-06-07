import Foundation

public protocol TogglePreferencesStore: AnyObject {
    func loadEnabledIDs() -> Set<String>
    func loadOrder() -> [String]
    func save(enabledIDs: Set<String>, order: [String])
}

public final class UserDefaultsTogglePreferencesStore: TogglePreferencesStore {
    private enum Keys {
        static let enabledIDs = "SwitchBar.enabledIDs"
        static let order = "SwitchBar.order"
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func loadEnabledIDs() -> Set<String> {
        let values = userDefaults.stringArray(forKey: Keys.enabledIDs) ?? []
        return Set(values)
    }

    public func loadOrder() -> [String] {
        userDefaults.stringArray(forKey: Keys.order) ?? []
    }

    public func save(enabledIDs: Set<String>, order: [String]) {
        userDefaults.set(Array(enabledIDs), forKey: Keys.enabledIDs)
        userDefaults.set(order, forKey: Keys.order)
    }
}
