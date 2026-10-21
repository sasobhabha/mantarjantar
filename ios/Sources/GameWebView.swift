import SwiftUI
import WebKit

/// The whole app: a WKWebView pointed at the game.
///
/// Mirrors the Android wrapper's behaviour:
///  - load the live game (https://mantarjantar.com) for online multiplayer;
///  - if that can't be reached (offline), fall back to the bundled copy of the
///    web client, where Practice (offline) mode works with no network at all;
///  - append "JantarMantarChaloApp" to the user agent so the page hides its
///    "Get the Android app" banner (it checks the UA for that string).
struct GameWebView: UIViewRepresentable {
    static let liveURL = URL(string: "https://mantarjantar.com")!

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "JantarMantarChaloApp"
        // Web Audio (the game's sound) should never require an extra media element gesture.
        config.mediaTypesRequiringUserActionForPlayback = []
        if let assetsRoot = Bundle.main.url(forResource: "WebAssets", withExtension: nil) {
            config.setURLSchemeHandler(
                LocalAssetSchemeHandler(assetsRoot: assetsRoot),
                forURLScheme: LocalAssetSchemeHandler.scheme
            )
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        // Matches the page's own background so there's no white flash while loading.
        webView.backgroundColor = UIColor(red: 0.561, green: 0.682, blue: 0.388, alpha: 1)

        // It's a game: keep the screen awake, like the Android app's keep-screen-on flag.
        UIApplication.shared.isIdleTimerDisabled = true

        context.coordinator.webView = webView
        context.coordinator.loadInitial()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        private var usingLocalFallback = false

        override init() {
            super.init()
            NotificationCenter.default.addObserver(
                self, selector: #selector(reloadGame), name: .jmcReload, object: nil
            )
        }

        @objc private func reloadGame() {
            usingLocalFallback = false
            loadInitial()
        }

        func loadInitial() {
            if ProcessInfo.processInfo.arguments.contains("-JMCOffline") {
                // Debug hook: force the bundled copy (used to test the offline path).
                usingLocalFallback = true
                jmcLog("[JMC] loading local fallback (forced)")
                webView?.load(LocalAssetSchemeHandler.localIndexRequest())
            } else {
                jmcLog("[JMC] loading live site")
                webView?.load(URLRequest(url: GameWebView.liveURL))
            }
        }

        func webView(
            _ webView: WKWebView, didFinish navigation: WKNavigation!
        ) {
            jmcLog("[JMC] didFinish: \(webView.url?.absoluteString ?? "nil")")
        }

        // The live site can't be reached (no network, DNS failure, timeout):
        // switch to the bundled copy so Practice offline still works.
        func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            let ns = error as NSError
            jmcLog("[JMC] didFailProvisionalNavigation domain=\(ns.domain) code=\(ns.code) url=\(webView.url?.absoluteString ?? "nil") failing=\(ns.userInfo[NSURLErrorFailingURLErrorKey] as? URL as Any) desc=\(ns.localizedDescription)")
            guard ns.domain == NSURLErrorDomain,
                  ns.code != NSURLErrorCancelled,
                  !usingLocalFallback,
                  Bundle.main.url(forResource: "WebAssets", withExtension: nil) != nil
            else { return }
            let failedURL = (ns.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? webView.url
            guard failedURL?.host?.hasSuffix("mantarjantar.com") == true else {
                jmcLog("[JMC] not falling back: failing host was \(failedURL?.host ?? "nil")")
                return
            }
            usingLocalFallback = true
            jmcLog("[JMC] falling back to bundled assets")
            webView.load(LocalAssetSchemeHandler.localIndexRequest())
        }

        // Links with target="_blank" (e.g. "About the game") open outside the app.
        func webView(
            _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            return nil
        }

        func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            jmcLog("[JMC] decidePolicy: \(url.absoluteString)")
            let scheme = url.scheme?.lowercased() ?? ""
            if ["http", "https", LocalAssetSchemeHandler.scheme, "about", "blob", "data"].contains(scheme) {
                decisionHandler(.allow)
            } else {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            }
        }
    }
}
