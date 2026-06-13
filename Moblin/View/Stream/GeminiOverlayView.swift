import SwiftUI
import WebKit

struct GeminiOverlayView: View {
    @ObservedObject var model: Model
    let previewSize: CGSize

    var body: some View {
        ZStack {
            // 1. Image Overlay
            if let imageURLString = model.geminiOverlayImageURL, let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: previewSize.width * 0.8, maxHeight: previewSize.height * 0.8)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    case .failure:
                        EmptyView()
                    case .empty:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    @unknown default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: model.geminiOverlayImageURL)
            }

            // 2. Text Overlay (Notification banner)
            if let overlayText = model.geminiOverlayText {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                            .font(.title3)

                        Text(overlayText)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                    .padding(.top, 40)
                    .transition(.move(edge: .top).combined(with: .opacity))

                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.geminiOverlayText)
            }

            // 3. YouTube Live Video Overlay
            if let youtubeURL = model.geminiOverlayYouTubeURL {
                GeometryReader { metrics in
                    let size = calculateYouTubeSize(metrics: metrics)
                    let offset = calculateYouTubeOffset(metrics: metrics, size: size)

                    ZStack(alignment: .topTrailing) {
                        YouTubeWebView(urlString: youtubeURL)
                            .frame(width: size.width, height: size.height)
                            .opacity(model.geminiOverlayYouTubeOpacity)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)

                        Button {
                            model.geminiOverlayYouTubeURL = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(8)
                        }
                    }
                    .offset(offset)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                .animation(.easeInOut(duration: 0.35), value: model.geminiOverlayYouTubeURL)
            }

            // 4. Voice Listening Panel
            if model.isGeminiListening {
                VStack {
                    Spacer()

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(model.geminiSpeechText == "Processando..." ? 0.3 : 1.0)
                                .animation(
                                    .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                                    value: model.isGeminiListening
                                )

                            Text("Gemini AI")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }

                        Text(model.geminiSpeechText)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)

                        if model.geminiSpeechText != String(localized: "Processing..."),
                           model.geminiSpeechText != String(localized: "Listening...")
                        {
                            Text(String(localized: "Toque no microfone novamente para enviar"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: min(previewSize.width - 32, 400))
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.isGeminiListening)
            }
        }
        .frame(width: previewSize.width, height: previewSize.height)
    }

    private func calculateYouTubeSize(metrics: GeometryProxy) -> CGSize {
        if model.geminiOverlayYouTubePosition == "fullscreen" {
            return metrics.size
        }
        let w = CGFloat(model.geminiOverlayYouTubeWidth)
        let h = CGFloat(model.geminiOverlayYouTubeHeight)
        return CGSize(width: min(w, metrics.size.width - 32), height: min(h, metrics.size.height - 32))
    }

    private func calculateYouTubeOffset(metrics: GeometryProxy, size: CGSize) -> CGSize {
        switch model.geminiOverlayYouTubePosition {
        case "top-left":
            CGSize(width: 16, height: 16)
        case "top-right":
            CGSize(width: metrics.size.width - size.width - 16, height: 16)
        case "bottom-left":
            CGSize(width: 16, height: metrics.size.height - size.height - 16)
        case "bottom-right":
            CGSize(
                width: metrics.size.width - size.width - 16,
                height: metrics.size.height - size.height - 16
            )
        case "fullscreen":
            .zero
        default: // center
            CGSize(
                width: (metrics.size.width - size.width) / 2,
                height: (metrics.size.height - size.height) / 2
            )
        }
    }
}

struct YouTubeWebView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context _: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaPlaybackRequiresUserAction = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        if let videoID = extractYouTubeVideoID(from: urlString) {
            let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
            body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background-color: transparent; }
            iframe { width: 100%; height: 100%; border: none; }
            </style>
            </head>
            <body>
            <iframe src="https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=1&mute=1&playsinline=1" 
                    allow="autoplay; encrypted-media; gyroscope; picture-in-picture" 
                    allowfullscreen>
            </iframe>
            </body>
            </html>
            """
            webView.loadHTMLString(htmlString, baseURL: URL(string: "https://www.youtube.com"))
        } else {
            if let url = URL(string: urlString) {
                var request = URLRequest(url: url)
                request.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
                webView.load(request)
            }
        }
        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    private func extractYouTubeVideoID(from url: String) -> String? {
        if url.contains("youtube.com/live/") {
            let parts = url.components(separatedBy: "youtube.com/live/")
            if parts.count > 1 {
                return parts[1].components(separatedBy: "?").first
            }
        }

        if url.contains("youtube.com/shorts/") {
            let parts = url.components(separatedBy: "youtube.com/shorts/")
            if parts.count > 1 {
                return parts[1].components(separatedBy: "?").first
            }
        }

        let pattern = "v=([^&]+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: url, options: [], range: NSRange(url.startIndex..., in: url))
        {
            if let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }

        if url.contains("youtu.be/") {
            let parts = url.components(separatedBy: "youtu.be/")
            if parts.count > 1 {
                return parts[1].components(separatedBy: "?").first
            }
        }

        if url.contains("youtube.com/embed/") {
            let parts = url.components(separatedBy: "youtube.com/embed/")
            if parts.count > 1 {
                return parts[1].components(separatedBy: "?").first
            }
        }

        return nil
    }
}
