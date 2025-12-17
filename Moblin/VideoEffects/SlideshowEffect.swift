import AVFoundation
import UIKit
import Vision

struct SlideshowEffectSlide {
    let widgetId: UUID
    let effect: VideoEffect
    let time: Double
}

final class SlideshowEffect: VideoEffect {
    let slides: [SlideshowEffectSlide]
    private var currentSlideIndex: Int = 0
    private var currentSlideEndTime: Double?

    init(slides: [SlideshowEffectSlide]) {
        self.slides = slides
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        for slide in slides {
            if let effect = slide.effect as? TextEffect {
                effect.setSceneWidget(sceneWidget: sceneWidget)
            } else if let effect = slide.effect as? ImageEffect {
                effect.setSceneWidget(sceneWidget: sceneWidget)
            } else {
                logger.info("slideshow-effect: Unsupported effect.")
            }
        }
    }

    override func getName() -> String {
        return "Slideshow"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let effect = getCurrentEffect(info.presentationTimeStamp.seconds) else {
            return image
        }
        return effect.execute(image, info)
    }

    private func getCurrentEffect(_ presentationTimeStamp: Double) -> VideoEffect? {
        guard !slides.isEmpty else {
            return nil
        }
        if let currentSlideEndTime {
            if presentationTimeStamp > currentSlideEndTime {
                currentSlideIndex += 1
                currentSlideIndex %= slides.count
                let slide = slides[currentSlideIndex]
                self.currentSlideEndTime = presentationTimeStamp + slide.time
                return slide.effect
            } else {
                return slides[currentSlideIndex].effect
            }
        } else {
            let slide = slides[currentSlideIndex]
            currentSlideEndTime = presentationTimeStamp + slide.time
            return slide.effect
        }
    }
}
