import SwiftUI
import WatchConnectivity

private class Cache {
    private var cache: [URL: Image] = [:]
    private var waiters: [URL: [(Image) -> Void]] = [:]
    private var waitingForResponse = false

    private func fetchImage(_ url: URL) {
        guard !waitingForResponse else {
            return
        }
        let message = [
            "type": "getImage",
            "data": url.absoluteString,
        ]
        waitingForResponse = true
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
                if let (url, _) = self.waiters.first {
                    self.fetchImage(url)
                }
            }
        }, errorHandler: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.waitingForResponse = false
                self.waiters.removeAll()
            }
        })
    }

    func get(_ url: URL, _ onImage: @escaping (Image) -> Void) -> Image? {
        if let image = cache[url] {
            return image
        }
        if waiters[url] == nil {
            waiters[url] = []
        }
        waiters[url]?.append(onImage)
        fetchImage(url)
        return nil
    }

    func set(_ url: URL, _ image: Image) {
        cache[url] = image
        if let onImages = waiters.removeValue(forKey: url) {
            for onImage in onImages {
                onImage(image)
            }
        }
    }
}

private let cache = Cache()

struct CacheImage<Content>: View where Content: View {
    private let url: URL
    private let content: (Image) -> Content
    @State var image: Image?

    init(url: URL, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.content = content
    }

    private func onImage(image: Image) {
        self.image = image
    }

    var body: some View {
        if let image = cache.get(url, onImage) {
            content(image)
        } else if let image {
            image
        } else {
            EmptyView()
        }
    }

    private func cacheAndRender(image: Image) -> some View {
        cache.set(url, image)
        return content(image)
    }
}
