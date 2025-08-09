import SwiftUI
import WebKit

// Global WebView instance to persist across app lifecycle
private var persistentWebView: WKWebView?

struct KickAuthView: View {
    @EnvironmentObject var model: Model
    @State private var showingWebView = false
    @State private var isLoading = false
    let stream: SettingsStream

    var body: some View {
        Form {
            Section {
                if stream.kickLoggedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Logged in to Kick")
                        Spacer()
                        Button("Log Out") {
                            logOut()
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    Button(action: {
                        showingWebView = true
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "person.crop.circle.badge.plus")
                            }
                            Text("Log in to Kick")
                        }
                    }
                    .disabled(isLoading)
                }
            } header: {
                Text("Authentication")
            } footer: {
                Text("Log in to Kick.com to send chat messages")
            }
        }
        .navigationTitle("Kick Authentication")
        .sheet(isPresented: $showingWebView) {
            NavigationView {
                VStack(spacing: 0) {
                    // Minimal toolbar
                    HStack {
                        Button("Cancel") {
                            showingWebView = false
                        }
                        Spacer()
                        Button("Clear Session") {
                            clearWebViewSession()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    
                    KickWebView(
                        onTokenExtracted: { token, sessionCookies in
                            handleTokenExtracted(token: token, cookies: sessionCookies)
                        }
                    )
                }
                .ignoresSafeArea(.keyboard)
            }
            .presentationDetents([.large])
        }
    }

    private func handleTokenExtracted(token: String?, cookies: [HTTPCookie]) {
        isLoading = true
        
        // Find session_token cookie
        if let sessionTokenCookie = cookies.first(where: { $0.name == "session_token" }) {
            let decodedToken = sessionTokenCookie.value.removingPercentEncoding ?? sessionTokenCookie.value
            
            DispatchQueue.main.async {
                stream.kickAccessToken = decodedToken
                stream.kickLoggedIn = true
                showingWebView = false
                isLoading = false
                
                model.makeToast(title: "Successfully logged in to Kick")
                
                if stream.enabled {
                    model.kickChannelNameUpdated()
                }
            }
        } else {
            DispatchQueue.main.async {
                isLoading = false
                model.makeErrorToast(title: "Login failed", subTitle: "Could not extract authentication token")
            }
        }
    }

    private func logOut() {
        stream.kickAccessToken = ""
        stream.kickLoggedIn = false
        
        model.makeToast(title: "Logged out from Kick")
        
        if stream.enabled {
            model.kickChannelNameUpdated()
        }
    }
    
    private func clearWebViewSession() {
        // Clear website data first
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) {
            DispatchQueue.main.async {
                // Clear and reload the persistent WebView
                if let webView = persistentWebView {
                    let url = URL(string: "https://kick.com/login")!
                    let request = URLRequest(url: url)
                    webView.load(request)
                }
                persistentWebView = nil
                
                self.model.makeToast(title: "WebView session cleared")
            }
        }
    }
}

struct KickWebView: UIViewRepresentable {
    let onTokenExtracted: (String?, [HTTPCookie]) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        // Use persistent WebView if it exists, otherwise create new one
        if let existingWebView = persistentWebView {
            existingWebView.navigationDelegate = context.coordinator
            return existingWebView
        }
        
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        // Enable better scrolling and keyboard handling
        configuration.preferences.javaScriptEnabled = true
        
        // Configure for persistence
        configuration.suppressesIncrementalRendering = false
        configuration.allowsInlineMediaPlayback = true
        configuration.processPool = WKProcessPool() // Shared process pool
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        
        // Allow zoom for better mobile experience
        webView.scrollView.minimumZoomScale = 0.5
        webView.scrollView.maximumZoomScale = 3.0
        webView.scrollView.bouncesZoom = true
        
        // Store globally for persistence
        persistentWebView = webView
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load URL if webView doesn't have content or is on a different domain
        if webView.url == nil || !(webView.url?.absoluteString.contains("kick.com") ?? false) {
            let url = URL(string: "https://kick.com/login")!
            let request = URLRequest(url: url)
            webView.load(request)
        }
        // Update the delegate in case it changed
        webView.navigationDelegate = context.coordinator
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: KickWebView
        
        init(_ parent: KickWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url?.absoluteString else { return }
            
            // Only extract token if we're on a logged-in page (not login/register page)
            if !url.contains("/login") && !url.contains("/register") && url.contains("kick.com") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.extractAuthToken(from: webView)
                }
            }
        }
        
        private func extractAuthToken(from webView: WKWebView) {
            // Get session cookies
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                let kickCookies = cookies.filter { $0.domain.contains("kick.com") }
                
                DispatchQueue.main.async {
                    if kickCookies.contains(where: { $0.name == "session_token" }) {
                        self.parent.onTokenExtracted(nil, kickCookies)
                    }
                }
            }
        }
    }
}