import AppKit
import WebKit
import MdreviewCore

enum ReaderLayout: String {
    case centered
    case withOutline
}

@MainActor
final class RendererViewController: NSViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private let webView: WKWebView
    private var isRendererLoaded = false
    private var pendingScripts = [String]()
    var onOutlineChanged: (([NativeOutlineItem]) -> Void)?
    var onOpenDocument: ((URL, String?) -> Void)?

    private enum PreviewZoom {
        static let minimum: CGFloat = 0.5
        static let maximum: CGFloat = 3
        static let step: CGFloat = 0.1
        static let actualSize: CGFloat = 1
    }

    init(resourceHandler: ResourceSchemeHandler) {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(resourceHandler, forURLScheme: "mdreview-resource")
        let contentController = WKUserContentController()
        configuration.userContentController = contentController
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        webView.navigationDelegate = self
        webView.allowsMagnification = true
        contentController.add(self, name: "mdreview")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = webView
    }

    func loadRenderer(from url: URL) {
        isRendererLoaded = false
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func render(path: String, name: String, content: String, scrollPosition: Double?, readerLayout: ReaderLayout) {
        let payload: [String: Any] = [
            "type": "renderDocument",
            "path": path,
            "name": name,
            "content": content,
            "scrollPosition": scrollPosition ?? 0,
            "readerLayout": readerLayout.rawValue
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        evaluateOrQueue("window.__mdreviewPendingDocument = \(json); window.__mdreviewRenderDocument && window.__mdreviewRenderDocument(window.__mdreviewPendingDocument);")
    }

    func setReaderLayout(_ readerLayout: ReaderLayout) {
        let value = readerLayout.rawValue
        evaluateOrQueue("window.__mdreviewPendingReaderLayout = '\(value)'; window.__mdreviewSetReaderLayout && window.__mdreviewSetReaderLayout(window.__mdreviewPendingReaderLayout);")
    }

    func scrollToHeading(id: String) {
        let escaped = id.replacingOccurrences(of: "'", with: "\\'")
        evaluateOrQueue("document.getElementById('\(escaped)')?.scrollIntoView({ block: 'start' });")
    }

    func zoomIn() {
        setPreviewZoom(webView.magnification + PreviewZoom.step)
    }

    func zoomOut() {
        setPreviewZoom(webView.magnification - PreviewZoom.step)
    }

    func resetZoom() {
        setPreviewZoom(PreviewZoom.actualSize)
    }

    private func setPreviewZoom(_ magnification: CGFloat) {
        let clamped = min(max(magnification, PreviewZoom.minimum), PreviewZoom.maximum)
        webView.setMagnification(clamped, centeredAt: NSPoint(x: webView.bounds.midX, y: webView.bounds.midY))
    }

    private func evaluateOrQueue(_ script: String) {
        guard isRendererLoaded else {
            pendingScripts.append(script)
            return
        }
        webView.evaluateJavaScript(script)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isRendererLoaded = true
        let scripts = pendingScripts
        pendingScripts.removeAll()
        for script in scripts {
            webView.evaluateJavaScript(script)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        switch RendererLinkNavigationPolicy.action(for: url) {
        case .allow:
            decisionHandler(.allow)
        case .openExternally(let externalURL):
            NSWorkspace.shared.open(externalURL)
            decisionHandler(.cancel)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        if type == "openDocument" {
            guard let path = body["path"] as? String,
                  !path.isEmpty else { return }
            let hash = body["hash"] as? String
            onOpenDocument?(URL(fileURLWithPath: path), hash?.isEmpty == true ? nil : hash)
            return
        }
        guard type == "outlineChanged",
              let rawItems = body["items"] as? [[String: Any]] else { return }
        let items = rawItems.compactMap { item -> NativeOutlineItem? in
            guard let id = item["id"] as? String,
                  let text = item["text"] as? String,
                  let depth = item["depth"] as? Int else { return nil }
            return NativeOutlineItem(id: id, text: text, depth: depth)
        }
        onOutlineChanged?(items)
    }
}
