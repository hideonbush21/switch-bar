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

final class MockFinderPreferenceManager: FinderPreferenceManaging {
    var values: [FinderPreferenceKey: Bool]
    var writes: [(FinderPreferenceKey, Bool)] = []
    var shouldWriteSucceed = true

    init(values: [FinderPreferenceKey: Bool] = [:]) {
        self.values = values
    }

    func readBool(key: FinderPreferenceKey, defaultValue: Bool) -> Bool {
        values[key] ?? defaultValue
    }

    func writeBool(_ value: Bool, key: FinderPreferenceKey) -> Bool {
        writes.append((key, value))
        guard shouldWriteSucceed else { return false }
        values[key] = value
        return true
    }
}

final class MockFinderReloader: FinderReloading {
    var policies: [FinderReopenPolicy] = []
    var shouldReloadSucceed = true

    func reloadFinder(reopenPolicy: FinderReopenPolicy) -> Bool {
        policies.append(reopenPolicy)
        return shouldReloadSucceed
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
    ("desktop icon service reads CreateDesktop false as hidden", {
        let preferences = MockFinderPreferenceManager(values: [.createDesktop: false])
        let service = FinderDesktopIconService(preferences: preferences, reloader: MockFinderReloader())

        try expect(service.areDesktopIconsHidden(), "CreateDesktop false should mean hidden desktop")
    }),
    ("desktop icon service reads CreateDesktop true as visible", {
        let preferences = MockFinderPreferenceManager(values: [.createDesktop: true])
        let service = FinderDesktopIconService(preferences: preferences, reloader: MockFinderReloader())

        try expect(!service.areDesktopIconsHidden(), "CreateDesktop true should mean visible desktop")
    }),
    ("desktop icon service defaults missing CreateDesktop to visible", {
        let preferences = MockFinderPreferenceManager()
        let service = FinderDesktopIconService(preferences: preferences, reloader: MockFinderReloader())

        try expect(!service.areDesktopIconsHidden(), "missing CreateDesktop key should mean visible desktop")
    }),
    ("desktop icon service hides icons by writing CreateDesktop false and reloading Finder", {
        let preferences = MockFinderPreferenceManager()
        let reloader = MockFinderReloader()
        let service = FinderDesktopIconService(preferences: preferences, reloader: reloader)

        let success = service.setDesktopIconsHidden(true)

        try expect(success, "hide desktop should succeed")
        try expectEqual(preferences.writes.map { $0.0 }, [.createDesktop], "hide desktop should only write CreateDesktop")
        try expectEqual(preferences.writes.map { $0.1 }, [false], "hide desktop should write CreateDesktop false")
        try expectEqual(reloader.policies, [.reopenIfUserHadFinderWindow], "hide desktop should use controlled Finder reload")
    }),
    ("desktop icon service shows icons by writing CreateDesktop true and reloading Finder", {
        let preferences = MockFinderPreferenceManager()
        let reloader = MockFinderReloader()
        let service = FinderDesktopIconService(preferences: preferences, reloader: reloader)

        let success = service.setDesktopIconsHidden(false)

        try expect(success, "show desktop should succeed")
        try expectEqual(preferences.writes.map { $0.0 }, [.createDesktop], "show desktop should only write CreateDesktop")
        try expectEqual(preferences.writes.map { $0.1 }, [true], "show desktop should write CreateDesktop true")
        try expectEqual(reloader.policies, [.reopenIfUserHadFinderWindow], "show desktop should use controlled Finder reload")
    }),
    ("hide desktop toggle delegates only to desktop icon service", {
        let preferences = MockFinderPreferenceManager()
        let reloader = MockFinderReloader()
        let toggle = HideDesktopToggle(service: FinderDesktopIconService(preferences: preferences, reloader: reloader))

        let success = toggle.apply(newValue: true)

        try expect(success, "hide desktop command should succeed")
        try expectEqual(preferences.writes.map { $0.0 }, [.createDesktop], "hide desktop toggle should not write hidden-files preference")
        try expectEqual(reloader.policies, [.reopenIfUserHadFinderWindow], "hide desktop toggle should not reload Finder directly")
    }),
    ("hidden files service writes only AppleShowAllFiles and reloads Finder", {
        let preferences = MockFinderPreferenceManager()
        let reloader = MockFinderReloader()
        let service = FinderHiddenFilesService(preferences: preferences, reloader: reloader)

        let success = service.setHiddenFilesVisible(true)

        try expect(success, "show hidden files should succeed")
        try expectEqual(preferences.writes.map { $0.0 }, [.appleShowAllFiles], "show hidden files should only write AppleShowAllFiles")
        try expectEqual(preferences.writes.map { $0.1 }, [true], "show hidden files should write true")
        try expectEqual(reloader.policies, [.reopenIfUserHadFinderWindow], "show hidden files should use controlled Finder reload")
    }),
    ("show hidden files toggle does not touch desktop icon preference", {
        let preferences = MockFinderPreferenceManager()
        let reloader = MockFinderReloader()
        let toggle = ShowHiddenFilesToggle(service: FinderHiddenFilesService(preferences: preferences, reloader: reloader))

        let success = toggle.apply(newValue: false)

        try expect(success, "hide hidden files should succeed")
        try expectEqual(preferences.writes.map { $0.0 }, [.appleShowAllFiles], "show hidden files toggle should not write CreateDesktop")
        try expectEqual(preferences.writes.map { $0.1 }, [false], "show hidden files toggle should write false")
        try expectEqual(reloader.policies, [.reopenIfUserHadFinderWindow], "show hidden files toggle should not reload Finder directly")
    }),
    ("Finder reloader never policy kills Finder without reopening it", {
        let shell = MockShellRunner()
        let reloader = FinderReloader(shell: shell, hadFinderWindow: { false })

        let success = reloader.reloadFinder(reopenPolicy: .never)

        try expect(success, "Finder reload should succeed")
        try expectEqual(shell.commands, ["killall Finder"], "never policy should not open Finder")
    }),
    ("Finder reloader reopens only when user had Finder window", {
        let shell = MockShellRunner()
        let reloader = FinderReloader(shell: shell, hadFinderWindow: { true })

        let success = reloader.reloadFinder(reopenPolicy: .reopenIfUserHadFinderWindow)

        try expect(success, "Finder reload should succeed")
        try expectEqual(shell.commands, [
            "killall Finder",
            "while ! pgrep -qx Finder; do sleep 0.05; done",
            "open -a Finder"
        ], "reopenIfUserHadFinderWindow should reopen only when predicate was true")
    }),
    ("Finder reloader treats Finder reopen failure as best effort", {
        let shell = MockShellRunner(results: [
            .success(""),
            .success(""),
            .failure(ShellError.nonZeroExit(code: 1, output: "open failed"))
        ])
        let reloader = FinderReloader(shell: shell, hadFinderWindow: { true })

        let success = reloader.reloadFinder(reopenPolicy: .reopenIfUserHadFinderWindow)

        try expect(success, "Finder reload should succeed even when reopening Finder fails")
        try expectEqual(shell.commands, [
            "killall Finder",
            "while ! pgrep -qx Finder; do sleep 0.05; done",
            "open -a Finder"
        ], "reopen failure should still attempt the expected best-effort commands")
    }),
    ("Finder reloader treats Finder wait failure as best effort", {
        let shell = MockShellRunner(results: [
            .success(""),
            .failure(ShellError.nonZeroExit(code: 1, output: "wait failed"))
        ])
        let reloader = FinderReloader(shell: shell, hadFinderWindow: { true })

        let success = reloader.reloadFinder(reopenPolicy: .reopenIfUserHadFinderWindow)

        try expect(success, "Finder reload should succeed even when waiting to reopen Finder fails")
        try expectEqual(shell.commands, [
            "killall Finder",
            "while ! pgrep -qx Finder; do sleep 0.05; done"
        ], "wait failure should not make the toggle fail")
    }),
    ("Finder reloader does not reopen when user had no Finder window", {
        let shell = MockShellRunner()
        let reloader = FinderReloader(shell: shell, hadFinderWindow: { false })

        let success = reloader.reloadFinder(reopenPolicy: .reopenIfUserHadFinderWindow)

        try expect(success, "Finder reload should succeed")
        try expectEqual(shell.commands, ["killall Finder"], "reopenIfUserHadFinderWindow should not open Finder without an existing window")
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
