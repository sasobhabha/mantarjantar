import Foundation
import WebKit

/// Serves the bundled copy of the web game (WebAssets/public, WebAssets/shared)
/// under a custom URL scheme, the iOS equivalent of Android's
/// WebViewAssetLoader + appassets.androidplatform.net.
///
/// Pages loaded from this scheme see a non-http(s) protocol, so the game's
/// client code correctly reports "online play unavailable" and enables only
/// Practice (offline) mode.
final class LocalAssetSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "jmclocal"

    private let assetsRoot: URL

    init(assetsRoot: URL) {
        self.assetsRoot = assetsRoot.resolvingSymlinksInPath()
    }

    /// Request for the bundled copy of the game, rooted at public/index.html.
    static func localIndexRequest() -> URLRequest {
        URLRequest(url: URL(string: "\(scheme)://app/public/index.html")!)
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        var path = url.path
        while path.hasPrefix("/") { path.removeFirst() }
        if path.isEmpty || path.hasSuffix("/") { path += "public/index.html" }

        let candidate = assetsRoot.appendingPathComponent(path).standardizedFileURL
        let rootPath = assetsRoot.path
        guard candidate.path.hasPrefix(rootPath + "/"),
              let data = try? Data(contentsOf: candidate),
              !data.isEmpty
        else {
            jmcLog("[JMC] scheme handler FAILED for \(path) (resolved \(candidate.path))")
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        jmcLog("[JMC] scheme handler served \(path) (\(data.count) bytes)")

        let response = URLResponse(
            url: url,
            mimeType: Self.mimeType(forExtension: candidate.pathExtension),
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Files are read synchronously, so there is nothing to cancel.
    }

    private static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html"
        case "js", "mjs": return "text/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "png": return "image/png"
        case "webp": return "image/webp"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        default: return "application/octet-stream"
        }
    }
}
