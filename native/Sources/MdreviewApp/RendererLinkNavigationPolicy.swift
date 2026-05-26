import Foundation

enum RendererLinkNavigationAction: Equatable {
    case allow
    case openExternally(URL)
}

enum RendererLinkNavigationPolicy {
    private static let externalSchemes: Set<String> = ["http", "https", "mailto"]

    static func action(for url: URL) -> RendererLinkNavigationAction {
        guard let scheme = url.scheme?.lowercased() else {
            return .allow
        }
        return externalSchemes.contains(scheme) ? .openExternally(url) : .allow
    }
}
