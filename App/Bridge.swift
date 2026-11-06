import Foundation
import WebKit

// Riceve i messaggi dalla pagina:
//  - "dmx":   valori DMX da inviare in Art-Net al nodo
//  - "save":  salvataggio di fari, preset e impostazioni
//  - "fetch": download di un profilo dalla libreria di QLC+ (internet)
final class Bridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    private let artnet = ArtNetSender()

    private var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dati-luci.json")
    }

    func loadSaved() -> String {
        guard let data = try? Data(contentsOf: saveURL),
              (try? JSONSerialization.jsonObject(with: data)) != nil,
              let text = String(data: data, encoding: .utf8) else { return "null" }
        return text
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let cmd = body["cmd"] as? String else { return }
        switch cmd {
        case "dmx":
            guard let ip = body["ip"] as? String,
                  let b64 = body["b64"] as? String,
                  let data = Data(base64Encoded: b64) else { return }
            let universe = (body["uni"] as? NSNumber)?.intValue ?? 0
            artnet.send(ip: ip, universe: universe, dmx: data)

        case "save":
            guard let json = body["json"] as? String, let data = json.data(using: .utf8) else { return }
            try? data.write(to: saveURL, options: .atomic)

        case "fetch":
            guard let id = (body["id"] as? NSNumber)?.intValue,
                  let text = body["url"] as? String,
                  let url = URL(string: text), url.scheme == "https" else { return }
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let ok = error == nil && status == 200
                let result: String
                if ok, let data = data, let s = String(data: data, encoding: .utf8) { result = s }
                else { result = error?.localizedDescription ?? "errore \(status)" }
                let encoded = (try? JSONSerialization.data(withJSONObject: [result]))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
                DispatchQueue.main.async {
                    self?.webView?.evaluateJavaScript("window.__luciFetchDone(\(id), \(ok), \(encoded)[0])", completionHandler: nil)
                }
            }.resume()

        default:
            break
        }
    }
}
