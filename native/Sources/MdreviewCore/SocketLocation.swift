import Darwin
import Foundation

public enum SocketLocation {
    public static func defaultPath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        let tmp = environment["TMPDIR"] ?? NSTemporaryDirectory()
        let trimmed = tmp.hasSuffix("/") ? String(tmp.dropLast()) : tmp
        return "\(trimmed)/mdreview-\(getuid()).sock"
    }
}
