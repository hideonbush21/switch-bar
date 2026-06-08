import Foundation

public enum FinderPreferenceKey: Equatable {
    case createDesktop
    case appleShowAllFiles

    var rawValue: String {
        switch self {
        case .createDesktop:
            return "CreateDesktop"
        case .appleShowAllFiles:
            return "AppleShowAllFiles"
        }
    }
}

public protocol FinderPreferenceManaging: AnyObject {
    func readBool(key: FinderPreferenceKey, defaultValue: Bool) -> Bool
    func writeBool(_ value: Bool, key: FinderPreferenceKey) -> Bool
}

public final class FinderPreferenceStore: FinderPreferenceManaging {
    private let shell: ShellRunning

    public init(shell: ShellRunning = ShellHelper()) {
        self.shell = shell
    }

    public func readBool(key: FinderPreferenceKey, defaultValue: Bool) -> Bool {
        do {
            let output = try shell.run("defaults read com.apple.finder \(key.rawValue)")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if output == "1" || output == "true" {
                return true
            }
            if output == "0" || output == "false" {
                return false
            }
            return defaultValue
        } catch {
            return defaultValue
        }
    }

    public func writeBool(_ value: Bool, key: FinderPreferenceKey) -> Bool {
        do {
            _ = try shell.run("defaults write com.apple.finder \(key.rawValue) -bool \(value ? "true" : "false")")
            return true
        } catch {
            return false
        }
    }
}
