import Foundation
import SwitchBarCore

private struct TestFailure: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure(message: message)
    }
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    if actual != expected {
        throw TestFailure(message: "\(message). expected=\(expected), actual=\(actual)")
    }
}

private func run(_ name: String, _ body: () throws -> Void) -> Bool {
    do {
        try body()
        print("PASS \(name)")
        return true
    } catch {
        print("FAIL \(name): \(error)")
        return false
    }
}

final class MockToggleProvider: ToggleProvider {
    let id: String
    let title: String
    let iconName: String
    let controlType: ControlType
    var subtitle: String?
    var isOn: Bool
    var applyResult = true
    var appliedValues: [Bool] = []
    var refreshCount = 0
    var onApply: (() -> Void)?

    init(
        id: String = "mock",
        title: String = "Mock",
        iconName: String = "switch.2",
        isOn: Bool = false,
        controlType: ControlType = .toggle
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.isOn = isOn
        self.controlType = controlType
    }

    func apply(newValue: Bool) -> Bool {
        appliedValues.append(newValue)
        onApply?()
        return applyResult
    }

    func refreshState() {
        refreshCount += 1
    }
}

final class InMemoryTogglePreferencesStore: TogglePreferencesStore {
    var enabledIDs: Set<String>
    var order: [String]
    var savedIsOnByID: [String: Bool] = [:]

    init(enabledIDs: Set<String> = [], order: [String] = []) {
        self.enabledIDs = enabledIDs
        self.order = order
    }

    func loadEnabledIDs() -> Set<String> {
        enabledIDs
    }

    func loadOrder() -> [String] {
        order
    }

    func save(enabledIDs: Set<String>, order: [String]) {
        self.enabledIDs = enabledIDs
        self.order = order
    }
}

final class MockShellRunner: ShellRunning {
    var commands: [String] = []
    private var results: [Result<String, Error>]

    init(outputs: [String] = []) {
        self.results = outputs.map { .success($0) }
    }

    init(results: [Result<String, Error>]) {
        self.results = results
    }

    func run(_ command: String) throws -> String {
        commands.append(command)
        guard !results.isEmpty else { return "" }
        return try results.removeFirst().get()
    }
}

private let tests: [(String, () throws -> Void)] = [
    ("toggle updates only after successful apply", {
        let provider = MockToggleProvider(isOn: false)
        let toggle = AnyToggleProvider(provider)

        toggle.requestSet(true)

        try expect(toggle.isOn, "toggle should turn on after successful apply")
        try expect(!toggle.isBusy, "toggle should not stay busy")
        try expect(toggle.errorMessage == nil, "successful apply should clear error")
        try expectEqual(provider.appliedValues, [true], "provider should receive requested value")
        try expect(provider.isOn, "provider state should be committed after success")
    }),
    ("failed apply keeps old state and shows error", {
        let provider = MockToggleProvider(isOn: false)
        provider.applyResult = false
        let toggle = AnyToggleProvider(provider)

        toggle.requestSet(true)

        try expect(!toggle.isOn, "failed apply should keep UI off")
        try expect(!provider.isOn, "failed apply should keep provider off")
        try expect(!toggle.isBusy, "failed apply should end busy state")
        try expectEqual(toggle.errorMessage, "操作失败，请稍后重试", "failed apply should show row error")
        try expectEqual(provider.refreshCount, 1, "failed apply should refresh real state")
    }),
    ("busy toggle ignores duplicate requests", {
        let provider = MockToggleProvider(isOn: false)
        let toggle = AnyToggleProvider(provider)
        provider.onApply = {
            toggle.requestSet(false)
        }

        toggle.requestSet(true)

        try expectEqual(provider.appliedValues, [true], "busy request should ignore reentrant request")
        try expect(toggle.isOn, "toggle should commit successful first request")
        try expect(!toggle.isBusy, "toggle should leave busy state")
    }),
    ("action does not retain on state", {
        let provider = MockToggleProvider(isOn: false, controlType: .action)
        let toggle = AnyToggleProvider(provider)

        toggle.triggerAction()

        try expect(!toggle.isOn, "action should not remain on")
        try expect(!provider.isOn, "action provider should not remain on")
        try expect(!toggle.isBusy, "action should leave busy state")
        try expect(toggle.errorMessage == nil, "successful action should not show error")
        try expectEqual(provider.appliedValues, [true], "action should apply true once")
    }),
    ("registry persists enabled IDs and order", {
        let store = InMemoryTogglePreferencesStore()
        let registry = ToggleRegistry(preferencesStore: store)
        let first = AnyToggleProvider(MockToggleProvider(id: "first"))
        let second = AnyToggleProvider(MockToggleProvider(id: "second"))
        let third = AnyToggleProvider(MockToggleProvider(id: "third"))

        registry.register(first)
        registry.register(second)
        registry.register(third)
        registry.enabledIDs = ["first", "third"]
        registry.order = ["third", "first", "second"]
        registry.saveState()

        let restored = ToggleRegistry(preferencesStore: store)
        restored.register(first)
        restored.register(second)
        restored.register(third)
        restored.loadState()

        try expectEqual(restored.visibleToggles.map { $0.id }, ["third", "first"], "visible toggles should follow saved order")
    }),
    ("registry ignores unknown IDs in saved order", {
        let store = InMemoryTogglePreferencesStore(
            enabledIDs: ["missing", "first"],
            order: ["missing", "first"]
        )
        let registry = ToggleRegistry(preferencesStore: store)
        let first = AnyToggleProvider(MockToggleProvider(id: "first"))

        registry.register(first)
        registry.loadState()

        try expectEqual(registry.visibleToggles.map { $0.id }, ["first"], "unknown saved IDs should be ignored")
    }),
    ("registry does not persist system toggle values", {
        let store = InMemoryTogglePreferencesStore()
        let provider = MockToggleProvider(id: "keepAwake", isOn: true)
        let registry = ToggleRegistry(preferencesStore: store)

        registry.register(AnyToggleProvider(provider))
        registry.saveState()

        try expect(store.savedIsOnByID["keepAwake"] == nil, "registry should not save isOn values")
    }),
    ("CreateDesktop false means hide desktop is on", {
        let shell = MockShellRunner(outputs: ["0"])
        let toggle = HideDesktopToggle(shell: shell)

        toggle.refreshState()

        try expect(toggle.isOn, "CreateDesktop false should mean hidden desktop")
    }),
    ("CreateDesktop true means hide desktop is off", {
        let shell = MockShellRunner(outputs: ["1"])
        let toggle = HideDesktopToggle(shell: shell)

        toggle.refreshState()

        try expect(!toggle.isOn, "CreateDesktop true should mean visible desktop")
    }),
    ("missing CreateDesktop key defaults to desktop visible", {
        let shell = MockShellRunner(results: [
            .failure(ShellError.nonZeroExit(code: 1, output: "does not exist"))
        ])
        let toggle = HideDesktopToggle(shell: shell)

        toggle.refreshState()

        try expect(!toggle.isOn, "missing key should default to desktop visible")
    }),
    ("apply hide desktop writes CreateDesktop false", {
        let shell = MockShellRunner()
        let toggle = HideDesktopToggle(shell: shell)

        let success = toggle.apply(newValue: true)

        try expect(success, "hide desktop command should succeed")
        try expectEqual(shell.commands, [
            "defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
        ], "hide desktop command should write false")
    }),
    ("apply show desktop writes CreateDesktop true", {
        let shell = MockShellRunner()
        let toggle = HideDesktopToggle(shell: shell)

        let success = toggle.apply(newValue: false)

        try expect(success, "show desktop command should succeed")
        try expectEqual(shell.commands, [
            "defaults write com.apple.finder CreateDesktop -bool true && killall Finder"
        ], "show desktop command should write true")
    })
]

let failures = tests.reduce(0) { count, test in
    count + (run(test.0, test.1) ? 0 : 1)
}

if failures > 0 {
    print("\n\(failures) test(s) failed")
    exit(1)
}

print("\nAll \(tests.count) tests passed")
