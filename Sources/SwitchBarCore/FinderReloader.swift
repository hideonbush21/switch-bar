import Foundation

public enum FinderReopenPolicy: Equatable {
    case never
    case reopenIfUserHadFinderWindow
    case always
}

public protocol FinderReloading: AnyObject {
    func reloadFinder(reopenPolicy: FinderReopenPolicy) -> Bool
}

public final class FinderReloader: FinderReloading {
    private let shell: ShellRunning
    private let hadFinderWindow: () -> Bool

    public init(
        shell: ShellRunning = ShellHelper(),
        hadFinderWindow: @escaping () -> Bool = FinderReloader.detectFinderWindow
    ) {
        self.shell = shell
        self.hadFinderWindow = hadFinderWindow
    }

    public func reloadFinder(reopenPolicy: FinderReopenPolicy) -> Bool {
        let shouldReopen: Bool
        switch reopenPolicy {
        case .never:
            shouldReopen = false
        case .always:
            shouldReopen = true
        case .reopenIfUserHadFinderWindow:
            shouldReopen = hadFinderWindow()
        }

        do {
            _ = try shell.run("killall Finder")
            guard shouldReopen else { return true }

            guard (try? shell.run("while ! pgrep -qx Finder; do sleep 0.05; done")) != nil else {
                return true
            }
            _ = try? shell.run("open -a Finder")
            return true
        } catch {
            return false
        }
    }

    public static func detectFinderWindow() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "tell application \"Finder\" to count of Finder windows"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return false }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"
            return (Int(output) ?? 0) > 0
        } catch {
            return false
        }
    }
}
