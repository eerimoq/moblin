import CoreImage
import Foundation

func toPixels(_ percentage: Double, _ total: Double) -> Double {
    return (percentage * total) / 100
}

func makeScale(_ image: CIImage,
               _ sceneWidget: SettingsSceneWidget,
               _ size: CGSize,
               _ mirror: Bool) -> CGAffineTransform
{
    var scaleX = toPixels(sceneWidget.width, size.width) / image.extent.size.width
    var scaleY = toPixels(sceneWidget.height, size.height) / image.extent.size.height
    let scale = min(scaleX, scaleY)
    if mirror {
        scaleX = -1 * scale
    } else {
        scaleX = scale
    }
    scaleY = scale
    return CGAffineTransform(scaleX: scaleX, y: scaleY)
}

func makeTranslation(_ image: CIImage,
                     _ sceneWidget: SettingsSceneWidget,
                     _ size: CGSize) -> CGAffineTransform
{
    let x = toPixels(sceneWidget.x, size.width)
    let y = size.height - toPixels(sceneWidget.y, size.height) - image.extent.height
    return CGAffineTransform(translationX: x, y: y)
}
