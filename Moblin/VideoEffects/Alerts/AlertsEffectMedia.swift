import AVFoundation
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

struct AlertsEffectPlayer {
    let images: AlertsEffectImages
    let soundUrl: URL?
}

class AlertsEffectMedia: @unchecked Sendable {
    private var mediaType: SettingsWidgetAlertsAlertMediaType = .gifAndSound
    private var gifImages: Deque<AlertsEffectGifImage> = []
    private var videoUrl: URL?
    private var soundUrl: URL?

    func getPlayer() -> AlertsEffectPlayer {
        let images: AlertsEffectImages
        switch mediaType {
        case .gifAndSound:
            images = AlertsEffectGifImages(images: gifImages)
        case .video:
            images = AlertsEffectVideoImages(videoUrl: videoUrl)
        }
        return AlertsEffectPlayer(images: images, soundUrl: soundUrl)
    }

    func update(_ alert: SettingsWidgetAlertsAlert,
                _ mediaStorage: AlertMediaStorage,
                _ bundledImages: [SettingsAlertsMediaGalleryItem],
                _ bundledSounds: [SettingsAlertsMediaGalleryItem])
    {
        mediaType = alert.mediaType
        switch alert.mediaType {
        case .gifAndSound:
            updateGifAndSound(alert, mediaStorage, bundledImages, bundledSounds)
        case .video:
            updateVideo(alert, mediaStorage)
        }
    }

    private func updateGifAndSound(_ alert: SettingsWidgetAlertsAlert,
                                   _ mediaStorage: AlertMediaStorage,
                                   _ bundledImages: [SettingsAlertsMediaGalleryItem],
                                   _ bundledSounds: [SettingsAlertsMediaGalleryItem])
    {
        updateGifAndSoundImages(alert, mediaStorage, bundledImages)
        updateGifAndSoundSoundUrl(alert, mediaStorage, bundledSounds)
    }

    private func updateVideo(_ alert: SettingsWidgetAlertsAlert, _ mediaStorage: AlertMediaStorage) {
        videoUrl = nil
        soundUrl = nil
        guard let filename = alert.makeVideoFilename() else {
            return
        }
        videoUrl = mediaStorage.videos.makePath(filename: filename)
        guard let videoUrl else {
            return
        }
        videoSoundLoader(path: videoUrl) {
            self.soundUrl = $0
        }
    }

    private func updateGifAndSoundImages(_ alert: SettingsWidgetAlertsAlert,
                                         _ mediaStorage: AlertMediaStorage,
                                         _ bundledImages: [SettingsAlertsMediaGalleryItem])
    {
        let image: AlertsEffectMediaItem
        if let bundledImage = bundledImages.first(where: { $0.id == alert.imageId }) {
            image = .bundledName(bundledImage.name)
        } else {
            image = .customUrl(mediaStorage.makePath(id: alert.imageId))
        }
        let loopCount = alert.imageLoopCount
        DispatchQueue.global().async {
            var images: Deque<AlertsEffectGifImage> = []
            switch image {
            case let .bundledName(name):
                if let url = Bundle.main.url(forResource: "Alerts.bundle/\(name)", withExtension: "gif") {
                    images = self.loadGifImages(url: url, loopCount: loopCount)
                }
            case let .customUrl(url):
                images = self.loadGifImages(url: url, loopCount: loopCount)
            case let .image(image):
                images = self.loadGifImages(image: image, loopCount: loopCount)
            }
            DispatchQueue.main.async {
                self.gifImages = images
            }
        }
    }

    private func updateGifAndSoundSoundUrl(_ alert: SettingsWidgetAlertsAlert,
                                           _ mediaStorage: AlertMediaStorage,
                                           _ bundledSounds: [SettingsAlertsMediaGalleryItem])
    {
        let sound: AlertsEffectMediaItem
        if let bundledSound = bundledSounds.first(where: { $0.id == alert.soundId }) {
            sound = .bundledName(bundledSound.name)
        } else {
            sound = .customUrl(mediaStorage.makePath(id: alert.soundId))
        }
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

    private func loadGifImages(url: URL, loopCount: Int) -> Deque<AlertsEffectGifImage> {
        var timeOffset = 0.0
        var images: Deque<AlertsEffectGifImage> = []
        for _ in 0 ..< loopCount {
            if let data = try? Data(contentsOf: url), let animatedImage = SDAnimatedImage(data: data) {
                for index in 0 ..< animatedImage.animatedImageFrameCount {
                    if let cgImage = animatedImage.animatedImageFrame(at: index)?.cgImage {
                        timeOffset += animatedImage.animatedImageDuration(at: index)
                        images.append(AlertsEffectGifImage(image: CIImage(cgImage: cgImage),
                                                           timeOffset: timeOffset))
                    }
                }
            }
        }
        return images
    }

    private func loadGifImages(image: CIImage, loopCount: Int) -> Deque<AlertsEffectGifImage> {
        var timeOffset = 0.0
        var images: Deque<AlertsEffectGifImage> = []
        for _ in 0 ..< loopCount {
            timeOffset += 1
            images.append(AlertsEffectGifImage(image: image, timeOffset: timeOffset))
        }
        return images
    }
}

protocol AlertsEffectImages {
    func getImage(_ presentationTimeStamp: Double) -> CIImage?
    func isEmpty() -> Bool
}

class AlertsEffectGifImages: AlertsEffectImages {
    private var images: Deque<AlertsEffectGifImage> = []
    private var basePresentationTimeStamp: Double?

    init() {}

    init(images: Deque<AlertsEffectGifImage>) {
        self.images = images
    }

    func getImage(_ presentationTimeStamp: Double) -> CIImage? {
        if basePresentationTimeStamp == nil {
            basePresentationTimeStamp = presentationTimeStamp
        }
        let timeOffset = presentationTimeStamp - basePresentationTimeStamp!
        while let image = images.first {
            if timeOffset >= image.timeOffset {
                images.removeFirst()
                continue
            }
            return image.image
        }
        return nil
    }

    func isEmpty() -> Bool {
        return images.isEmpty
    }
}

class AlertsEffectVideoImages: AlertsEffectImages {
    init(videoUrl _: URL?) {}

    func getImage(_: Double) -> CIImage? {
        return nil
    }

    func isEmpty() -> Bool {
        return true
    }
}

private func videoSoundLoader(path: URL, onCompleted: @escaping (URL?) -> Void) {
    let asset = AVAsset(url: path)
    guard let reader = try? AVAssetReader(asset: asset) else {
        onCompleted(nil)
        return
    }
    asset.loadTracks(withMediaType: .audio) { tracks, error in
        guard let track = tracks?.first, error == nil else {
            onCompleted(nil)
            return
        }
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 48000.0,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(trackOutput)
        reader.startReading()
        var samples: [Int16] = []
        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            guard let data = sampleBuffer.dataBuffer?.data else {
                continue
            }
            let reader = ByteReader(data: data)
            while reader.bytesAvailable > 0, let sample = try? reader.readUInt16Le() {
                samples.append(Int16(bitPattern: sample))
            }
        }
        let wav = createWav(sampleRate: 48000, samples: [samples])
        let soundUrl = path.appendingPathExtension("wav")
        guard FileManager.default.createFile(atPath: soundUrl.path(), contents: wav) else {
            onCompleted(nil)
            return
        }
        onCompleted(soundUrl)
    }
}
