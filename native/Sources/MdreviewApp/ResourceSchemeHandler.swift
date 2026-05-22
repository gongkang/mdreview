import Foundation
import WebKit
import MdreviewCore

final class ResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    var root: URL?
    var currentDocument: URL?

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let root, let currentDocument else {
            urlSchemeTask.didFailWithError(PathValidationError.unsupportedPath)
            return
        }
        do {
            let resource = try ResourceURL.parse(urlSchemeTask.request.url!)
            let file = try ResourceAuthorizer(root: root).resolve(resource: resource, from: currentDocument)
            let data = try Data(contentsOf: file)
            let response = URLResponse(url: urlSchemeTask.request.url!, mimeType: mimeType(for: file), expectedContentLength: data.count, textEncodingName: nil)
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        default: return "application/octet-stream"
        }
    }
}
