import SwiftUI
import WebKit

// App per iPad: mostra l'interfaccia della Centralina Luci (web/index.html, inclusa nell'app)
// e manda l'Art-Net direttamente dall'iPad al nodo DMX.
@main
struct CentralinaLuciApp: App {
    var body: some Scene {
        WindowGroup {
            LuciWebView()
                .ignoresSafeArea()
                .statusBarHidden(true)
                .background(Color(red: 0.05, green: 0.06, blue: 0.08))
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true } // lo schermo non si spegne durante lo spettacolo
        }
    }
}

struct LuciWebView: UIViewRepresentable {
    func makeCoordinator() -> Bridge { Bridge() }

    func makeUIView(context: Context) -> WKWebView {
        let bridge = context.coordinator
        let contents = WKUserContentController()
        contents.add(bridge, name: "luci")
        // dati salvati (fari, preset, impostazioni) passati alla pagina prima che parta
        let saved = bridge.loadSaved()
        contents.addUserScript(WKUserScript(source: "window.__LUCI_DATA = \(saved);",
                                            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let config = WKWebViewConfiguration()
        config.userContentController = contents

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1)
        web.scrollView.backgroundColor = web.backgroundColor
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        if #available(iOS 16.4, *) { web.isInspectable = true }
        bridge.webView = web

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
