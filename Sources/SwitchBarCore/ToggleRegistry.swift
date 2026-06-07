import Combine
import Foundation

public final class ToggleRegistry: ObservableObject {
    @Published public var toggles: [AnyToggleProvider] = []
    @Published public var enabledIDs: Set<String> = []
    @Published public var order: [String] = []

    private let preferencesStore: TogglePreferencesStore

    public init(preferencesStore: TogglePreferencesStore = UserDefaultsTogglePreferencesStore()) {
        self.preferencesStore = preferencesStore
    }

    public var visibleToggles: [AnyToggleProvider] {
        order.compactMap { id in
            toggles.first { $0.id == id && enabledIDs.contains(id) }
        }
    }

    public var orderedToggles: [AnyToggleProvider] {
        order.compactMap { id in
            toggles.first { $0.id == id }
        }
    }

    public func register(_ provider: AnyToggleProvider) {
        guard toggles.contains(where: { $0.id == provider.id }) == false else { return }

        toggles.append(provider)
        if order.contains(provider.id) == false {
            order.append(provider.id)
        }
        if enabledIDs.isEmpty {
            enabledIDs.insert(provider.id)
        }
    }

    public func refreshAll() {
        toggles.forEach { $0.refreshState() }
    }

    public func setEnabled(_ isEnabled: Bool, for id: String) {
        if isEnabled {
            enabledIDs.insert(id)
        } else {
            enabledIDs.remove(id)
        }
        saveState()
    }

    public func moveToggle(from source: IndexSet, to destination: Int) {
        let movingIDs = source.map { order[$0] }
        for index in source.sorted(by: >) {
            order.remove(at: index)
        }

        var insertionIndex = destination
        for sourceIndex in source where sourceIndex < destination {
            insertionIndex -= 1
        }

        order.insert(contentsOf: movingIDs, at: insertionIndex)
        saveState()
    }

    public func saveState() {
        preferencesStore.save(enabledIDs: enabledIDs, order: order)
    }

    public func loadState() {
        let knownIDs = Set(toggles.map { $0.id })
        let loadedEnabledIDs = preferencesStore.loadEnabledIDs().intersection(knownIDs)
        let loadedOrder = preferencesStore.loadOrder().filter { knownIDs.contains($0) }

        enabledIDs = loadedEnabledIDs.isEmpty ? knownIDs : loadedEnabledIDs
        order = loadedOrder + toggles.map { $0.id }.filter { loadedOrder.contains($0) == false }
    }
}
