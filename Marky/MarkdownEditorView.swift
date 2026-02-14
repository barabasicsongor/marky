import SwiftUI
import WebKit

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContent = config.userContentController
        userContent.add(context.coordinator, name: "editorReady")
        userContent.add(context.coordinator, name: "contentChanged")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        if let htmlURL = Bundle.main.url(forResource: "editor", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            NSLog("[Marky] ERROR: editor.html not found in bundle")
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        guard coordinator.isEditorReady,
              !coordinator.isUpdatingFromJS,
              coordinator.lastSentMarkdown != markdown
        else { return }

        coordinator.sendMarkdownToEditor(markdown)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: MarkdownEditorView
        var webView: WKWebView?
        var isEditorReady = false
        var isUpdatingFromJS = false
        var lastSentMarkdown: String?

        init(_ parent: MarkdownEditorView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "editorReady":
                isEditorReady = true
                sendMarkdownToEditor(parent.markdown)

            case "contentChanged":
                guard let md = message.body as? String else { return }
                isUpdatingFromJS = true
                lastSentMarkdown = md
                parent.markdown = md
                DispatchQueue.main.async {
                    self.isUpdatingFromJS = false
                }

            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            NSLog("[Marky] Navigation failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            NSLog("[Marky] Provisional navigation failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            NSLog("[Marky] Page loaded successfully")
        }

        func sendMarkdownToEditor(_ md: String) {
            let escaped = md
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")

            lastSentMarkdown = md
            webView?.evaluateJavaScript("setMarkdown(`\(escaped)`)")
        }
    }
}
