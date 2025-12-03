import Collections
import CoreImage
import SDWebImage

enum AlertsEffectMediaItem {
    case bundledName(String)
    case customUrl(URL)
    case image(CIImage)
}

struct AlertsEffectGifImage {
    let image: CIImage
    let timeOffset: Double
}

class AlertsEffectMedia: @unchecked Sendable {
    var images: Deque<AlertsEffectGifImage> = []
    var soundUrl: URL?

    func updateSoundUrl(sound: AlertsEffectMediaItem) {
        switch sound {
        case let .bundledName(name):
            soundUrl = Bundle.main.url(forResource: "Alerts.bundle/\(name)", withExtension: "mp3")
        case let .customUrl(url):
            if (try? url.checkResourceIsReachable()) == true {
                soundUrl = url
            } else {
                soundUrl = nil
            }
        case .image:
            break
        }
    }

    func updateImages(image: AlertsEffectMediaItem, loopCount: Int) {
        DispatchQueue.global().async {
            var images: Deque<AlertsEffectGifImage> = []
            switch image {
            case let .bundledName(name):
                if let url = Bundle.main.url(forResource: "Alerts.bundle/\(name)", withExtension: "gif") {
                    images = self.loadImages(url: url, loopCount: loopCount)
                }
            case let .customUrl(url):
                images = self.loadImages(url: url, loopCount: loopCount)
            case let .image(image):
                images = self.loadImages(image: image, loopCount: loopCount)
            }
            processorPipelineQueue.async {
                self.images = images
            }
        }
    }

    private func loadImages(url: URL, loopCount: Int) -> Deque<AlertsEffectGifImage> {
        var timeOffset = 0.0
        var images: Deque<AlertsEffectGifImage> = []
        for _ in 0 ..< loopCount {
            if let data = try? Data(contentsOf: url), let animatedImage = SDAnimatedImage(data: data) {
                for index in 0 ..< animatedImage.animatedImageFrameCount {
                    if let cgImage = animatedImage.animatedImageFrame(at: index)?.cgImage {
                        timeOffset += animatedImage.animatedImageDuration(at: index)
                        images.append(AlertsEffectGifImage(image: CIImage(cgImage: cgImage), timeOffset: timeOffset))
                    }
                }
            }
        }
        return images
    }

    private func loadImages(image: CIImage, loopCount: Int) -> Deque<AlertsEffectGifImage> {
        var timeOffset = 0.0
        var images: Deque<AlertsEffectGifImage> = []
        for _ in 0 ..< loopCount {
            timeOffset += 1
            images.append(AlertsEffectGifImage(image: image, timeOffset: timeOffset))
        }
        return images
    }
}
