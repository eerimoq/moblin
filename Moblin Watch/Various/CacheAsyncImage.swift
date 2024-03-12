import SwiftUI
import WatchConnectivity

private class Cache {
    private var cache: [URL: Image] = [:]
    private var waitingForResponse = false

    private func fetchImage(_ url: URL) {
        guard !waitingForResponse else {
            return
        }
        let message = [
            "type": "getImage",
            "data": url.absoluteString,
        ]
        WCSession.default.sendMessage(message, replyHandler: { message in
            guard let data = message["data"] as? Data else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.waitingForResponse = false
                if let uiImage = UIImage(data: data) {
                    self.set(url, Image(uiImage: uiImage))
                } else {
                    self.set(url, Image("UnsupportedEmotePlaceholder"))
                }
            }
        }, errorHandler: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.waitingForResponse = false
            }
        })
        waitingForResponse = true
    }

    func get(_ url: URL) -> Image? {
        if let image = cache[url] {
            return image
        }
        fetchImage(url)
        return nil
    }

    func set(_ url: URL, _ image: Image) {
        cache[url] = image
    }
}

private let cache = Cache()

struct CacheAsyncImage<Content, Content2>: View where Content: View, Content2: View {
    private let url: URL
    private let scale: CGFloat
    private let content: (Image) -> Content
    private let placeholder: () -> Content2

    init(url: URL,
         scale: CGFloat = 1,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Content2)
    {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        if let image = cache.get(url) {
            content(image)
        } else {
            placeholder()
        }
    }

    private func cacheAndRender(image: Image) -> some View {
        cache.set(url, image)
        return content(image)
    }
}
