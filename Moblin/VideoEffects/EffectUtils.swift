import CoreImage
import Foundation

func toPixels(_ percentage: Double, _ total: Double) -> Double {
    return (percentage * total) / 100
}

extension CIImage {
    func resizeMoveMirror(_ sceneWidget: SettingsSceneWidget,
                          _ streamSize: CGSize,
                          _ mirror: Bool) -> CIImage
    {
        var scaleX = toPixels(sceneWidget.width, streamSize.width) / extent.size.width
        var scaleY = toPixels(sceneWidget.height, streamSize.height) / extent.size.height
        let scale = min(scaleX, scaleY)
        if mirror {
            scaleX = -1 * scale
        } else {
            scaleX = scale
        }
        scaleY = scale
        var x = toPixels(sceneWidget.x, streamSize.width)
        if mirror {
            x -= extent.width * scaleX
        }
        let y = streamSize.height - toPixels(sceneWidget.y, streamSize.height) - extent.height * scaleY
        return transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(translationX: x, y: y))
    }
}
