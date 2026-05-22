import Foundation

public enum PathValidationError: Error, Equatable {
    case pathEscapesRoot
    case unsupportedPath
}

public enum PathValidation {
    public static func canonicalURL(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    public static func realPath(inside root: URL, relativePath: String) throws -> URL {
        let candidate = root.appendingPathComponent(relativePath)
        let realRoot = canonicalURL(root)
        let realCandidate = canonicalURL(candidate)
        let rootPath = realRoot.path.hasSuffix("/") ? realRoot.path : realRoot.path + "/"
        if realCandidate.path == realRoot.path || realCandidate.path.hasPrefix(rootPath) {
            return realCandidate
        }
        throw PathValidationError.pathEscapesRoot
    }

    public static func isMarkdown(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasSuffix(".md") || lower.hasSuffix(".markdown")
    }
}
