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
        let image = transformed(by: makeScale(sceneWidget, streamSize, mirror))
        return image.transformed(by: image.makeTranslation(sceneWidget, streamSize))
    }

    private func makeScale(_ sceneWidget: SettingsSceneWidget,
                           _ streamSize: CGSize,
                           _ mirror: Bool) -> CGAffineTransform
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
        return CGAffineTransform(scaleX: scaleX, y: scaleY)
    }

    private func makeTranslation(_ sceneWidget: SettingsSceneWidget, _ streamSize: CGSize) -> CGAffineTransform {
        let x = toPixels(sceneWidget.x, streamSize.width)
        let y = streamSize.height - toPixels(sceneWidget.y, streamSize.height) - extent.height
        return CGAffineTransform(translationX: x, y: y)
    }
}
