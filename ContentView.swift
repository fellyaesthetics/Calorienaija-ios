import SwiftUI
import WebKit
import StoreKit

struct ContentView: View {
    @StateObject private var storeManager = StoreManager()
    @State private var showPaywall = false
    
    var body: some View {
        ZStack {
            WebView(url: URL(string: "https://www.calorienaija.com")!, storeManager: storeManager, showPaywall: $showPaywall)
                .edgesIgnoringSafeArea(.all)
            
            if showPaywall {
                PaywallView(storeManager: storeManager, isPresented: $showPaywall)
            }
        }
    }
}

// MARK: - Paywall View
struct PaywallView: View {
    @ObservedObject var storeManager: StoreManager
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                // Title
                VStack(spacing: 8) {
                    Text("CalorieNaija Pro")
                        .font(.title.bold())
                    Text("Unlock all premium features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Features
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "sparkles", text: "AI Nutrition Coach")
                    FeatureRow(icon: "camera.fill", text: "Unlimited Snap & Track")
                    FeatureRow(icon: "book.fill", text: "Premium Recipes")
                    FeatureRow(icon: "chart.bar.fill", text: "Advanced Analytics")
                    FeatureRow(icon: "fork.knife", text: "Personalized Meal Plans")
                }
                .padding(.horizontal)
                
                // Products
                if storeManager.isLoading {
                    ProgressView()
                        .padding()
                } else if let product = storeManager.products.first {
                    Button(action: {
                        Task {
                            _ = try? await storeManager.purchase(product)
                            if storeManager.isPro {
                                isPresented = false
                            }
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text("Subscribe for \(product.displayPrice)/month")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Cancel anytime")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                } else {
                    Text("Unable to load subscription. Please try again.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                    
                    Button("Retry") {
                        Task { await storeManager.loadProducts() }
                    }
                    .padding(.horizontal)
                }
                
                // Restore
                Button("Restore Purchases") {
                    Task {
                        await storeManager.restorePurchases()
                        if storeManager.isPro {
                            isPresented = false
                        }
                    }
                }
                .font(.footnote)
                .foregroundColor(.blue)
                
                // Error
                if let error = storeManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Legal links
                HStack(spacing: 16) {
                    Link("Terms of Use", destination: URL(string: "https://www.calorienaija.com/terms")!)
                    Link("Privacy Policy", destination: URL(string: "https://www.calorienaija.com/privacy")!)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 24)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - WebView with IAP Bridge
struct WebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var storeManager: StoreManager
    @Binding var showPaywall: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        // Add message handlers for IAP bridge
        let contentController = configuration.userContentController
        contentController.add(context.coordinator, name: "iapBridge")
        
        // Inject JavaScript bridge that the web app can call
        let bridgeScript = WKUserScript(
            source: """
            window.webkit = window.webkit || {};
            window.webkit.messageHandlers = window.webkit.messageHandlers || {};
            window.nativeIAP = {
                requestPurchase: function() {
                    window.webkit.messageHandlers.iapBridge.postMessage({action: 'purchase'});
                },
                restorePurchases: function() {
                    window.webkit.messageHandlers.iapBridge.postMessage({action: 'restore'});
                },
                getSubscriptionStatus: function() {
                    window.webkit.messageHandlers.iapBridge.postMessage({action: 'status'});
                }
            };
            // Signal to the web app that native IAP is available
            window.isNativeIOSApp = true;
            document.dispatchEvent(new CustomEvent('nativeIAPReady'));
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(bridgeScript)
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = true
        webView.navigationDelegate = context.coordinator
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        context.coordinator.webView = webView
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Send subscription status updates to web app
        let isPro = storeManager.isPro
        let js = "window.nativeSubscriptionStatus = {isPro: \(isPro)}; document.dispatchEvent(new CustomEvent('subscriptionStatusChanged', {detail: {isPro: \(isPro)}}));"
        uiView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        // Handle messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }
            
            Task { @MainActor in
                switch action {
                case "purchase":
                    self.parent.showPaywall = true
                    
                case "restore":
                    await self.parent.storeManager.restorePurchases()
                    self.sendStatusToWeb()
                    
                case "status":
                    self.sendStatusToWeb()
                    
                default:
                    break
                }
            }
        }
        
        // Send subscription status back to web app
        private func sendStatusToWeb() {
            let isPro = parent.storeManager.isPro
            let js = "window.nativeSubscriptionStatus = {isPro: \(isPro)}; document.dispatchEvent(new CustomEvent('subscriptionStatusChanged', {detail: {isPro: \(isPro)}}));"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
        
        // Handle navigation
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                // Allow calorienaija.com and its subdomains
                if let host = url.host, (host.contains("calorienaija.com") || host.contains("manus.space")) {
                    decisionHandler(.allow)
                    return
                }
                // Allow about:blank and other internal URLs
                if url.scheme == "about" || url.scheme == "blob" {
                    decisionHandler(.allow)
                    return
                }
                // Open external links in Safari
                if navigationAction.navigationType == .linkActivated {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}

#Preview {
    ContentView()
}
