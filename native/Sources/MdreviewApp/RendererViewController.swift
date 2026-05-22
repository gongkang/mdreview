import AppKit
import WebKit
import MdreviewCore

@MainActor
final class RendererViewController: NSViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private let webView: WKWebView
    private var isRendererLoaded = false
    private var pendingScript: String?
    var onOutlineChanged: (([NativeOutlineItem]) -> Void)?

    init(resourceHandler: ResourceSchemeHandler) {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(resourceHandler, forURLScheme: "mdreview-resource")
        let contentController = WKUserContentController()
        configuration.userContentController = contentController
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        webView.navigationDelegate = self
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

    func render(path: String, name: String, content: String, scrollPosition: Double?) {
        let payload: [String: Any] = ["type": "renderDocument", "path": path, "name": name, "content": content, "scrollPosition": scrollPosition ?? 0]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        evaluateOrQueue("window.__mdreviewPendingDocument = \(json); window.__mdreviewRenderDocument && window.__mdreviewRenderDocument(window.__mdreviewPendingDocument);")
    }

    func scrollToHeading(id: String) {
        let escaped = id.replacingOccurrences(of: "'", with: "\\'")
        evaluateOrQueue("document.getElementById('\(escaped)')?.scrollIntoView({ block: 'start' });")
    }

    private func evaluateOrQueue(_ script: String) {
        guard isRendererLoaded else {
            pendingScript = script
            return
        }
        webView.evaluateJavaScript(script)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isRendererLoaded = true
        if let pendingScript {
            self.pendingScript = nil
            webView.evaluateJavaScript(pendingScript)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
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
