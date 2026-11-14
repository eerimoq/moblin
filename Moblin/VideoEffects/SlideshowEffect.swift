import CoreImage
import MetalPetal

struct SlideshowEffectSlide {
    let widgetId: UUID
    let effect: VideoEffect
    let time: Double
}

final class SlideshowEffect: VideoEffect, @unchecked Sendable {
    let slides: [SlideshowEffectSlide]
    private var currentSlideIndex: Int = 0
    private var currentSlideEndTime: Double?
    private var preparedSlideIndex: Int = 0

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

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let (effect, prepareEffect) = getEffects(info.presentationTimeStamp.seconds)
        prepareEffect?.prepare(image.extent.size, info)
        return effect?.execute(image, info) ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        let (effect, prepareEffect) = getEffects(info.presentationTimeStamp.seconds)
        prepareEffect?.prepare(image.extent.size, info)
        return effect?.executeMetalPetal(image, info) ?? image
    }

    private func getEffects(_ presentationTimeStamp: Double) -> (VideoEffect?, VideoEffect?) {
        guard !slides.isEmpty else {
            return (nil, nil)
        }
        if let currentSlideEndTime {
            if presentationTimeStamp + 0.25 > currentSlideEndTime {
                var prepareEffect: VideoEffect?
                let nextSlideIndex = (currentSlideIndex + 1) % slides.count
                if nextSlideIndex != preparedSlideIndex {
                    prepareEffect = slides[nextSlideIndex].effect
                    preparedSlideIndex = nextSlideIndex
                }
                if presentationTimeStamp > currentSlideEndTime {
                    currentSlideIndex = nextSlideIndex
                    let slide = slides[currentSlideIndex]
                    self.currentSlideEndTime = presentationTimeStamp + slide.time
                    return (slide.effect, prepareEffect)
                } else {
                    return (slides[currentSlideIndex].effect, prepareEffect)
                }
            } else {
                return (slides[currentSlideIndex].effect, nil)
            }
        } else {
            let slide = slides[currentSlideIndex]
            currentSlideEndTime = presentationTimeStamp + slide.time
            return (slide.effect, nil)
        }
    }
}
