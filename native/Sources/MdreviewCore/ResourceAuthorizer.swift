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
        let realRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let candidate: URL
        if resource.hasPrefix("/") {
            let absoluteCandidate = URL(fileURLWithPath: resource).resolvingSymlinksInPath().standardizedFileURL
            if isInside(absoluteCandidate, root: realRoot) {
                return absoluteCandidate
            }
            if FileManager.default.fileExists(atPath: absoluteCandidate.path) {
                throw PathValidationError.pathEscapesRoot
            }
            candidate = realRoot
                .appendingPathComponent(String(resource.drop(while: { $0 == "/" })))
                .resolvingSymlinksInPath()
                .standardizedFileURL
        } else {
            let base = document.deletingLastPathComponent()
            candidate = base.appendingPathComponent(resource).resolvingSymlinksInPath().standardizedFileURL
        }
        guard isInside(candidate, root: realRoot) else {
            throw PathValidationError.pathEscapesRoot
        }
        return candidate
    }

    private func isInside(_ candidate: URL, root realRoot: URL) -> Bool {
        let rootPrefix = realRoot.path.hasSuffix("/") ? realRoot.path : realRoot.path + "/"
        return candidate.path == realRoot.path || candidate.path.hasPrefix(rootPrefix)
    }
}
