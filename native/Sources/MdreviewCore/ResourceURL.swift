import Foundation

public enum ResourceURLError: Error {
    case invalidScheme
    case missingPath
}

public enum ResourceURL {
    public static func parse(_ url: URL) throws -> String {
        guard url.scheme == "mdreview-resource" else { throw ResourceURLError.invalidScheme }
        let host = url.host ?? ""
        let path = url.path
        let combined = host + path
        guard !combined.isEmpty else { throw ResourceURLError.missingPath }
        return combined.removingPercentEncoding ?? combined
    }
}
