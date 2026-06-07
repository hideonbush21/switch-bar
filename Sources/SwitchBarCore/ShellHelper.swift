import Foundation

public enum ShellError: Error, CustomStringConvertible {
    case nonZeroExit(code: Int32, output: String)

    public var description: String {
        switch self {
        case let .nonZeroExit(code, output):
            return "Command exited with \(code): \(output)"
        }
    }
}

public protocol ShellRunning: AnyObject {
    func run(_ command: String) throws -> String
}

public final class ShellHelper: ShellRunning {
    public init() {}

    @discardableResult
    public func run(_ command: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw ShellError.nonZeroExit(code: process.terminationStatus, output: output)
        }

        return output
    }
}
