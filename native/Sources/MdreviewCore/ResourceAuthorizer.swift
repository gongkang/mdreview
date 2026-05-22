import Foundation

public struct ResourceAuthorizer {
    private let root: URL

    public init(root: URL) {
        self.root = root
    }

    public func resolve(resource: String, from document: URL) throws -> URL {
        if resource.contains("://") {
            throw PathValidationError.unsupportedPath
        }
        let base = document.deletingLastPathComponent()
        let candidate = base.appendingPathComponent(resource).resolvingSymlinksInPath().standardizedFileURL
        let realRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let rootPrefix = realRoot.path.hasSuffix("/") ? realRoot.path : realRoot.path + "/"
        guard candidate.path == realRoot.path || candidate.path.hasPrefix(rootPrefix) else {
            throw PathValidationError.pathEscapesRoot
        }
        return candidate
    }
}
