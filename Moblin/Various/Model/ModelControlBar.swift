import Foundation
import SwiftUI

let controlBarBackgroundImagePath = URL.documentsDirectory
    .appending(component: "controlBarBackgroundImage.img")

extension Model {
    func saveControlBarBackgroundImage(data: Data) {
        try? data.write(to: controlBarBackgroundImagePath)
        let quickButtons = database.quickButtonsGeneral
        quickButtons.backgroundImageCropX = 0
        quickButtons.backgroundImageCropY = 0
        quickButtons.backgroundImageCropWidth = 1
        quickButtons.backgroundImageCropHeight = 1
        updateControlBarBackgroundImage(image: UIImage(data: data))
    }

    func readControlBarBackgroundImage() -> UIImage? {
        guard let data = try? Data(contentsOf: controlBarBackgroundImagePath) else {
            return nil
        }
        return UIImage(data: data)
    }

    func loadControlBarBackgroundImage() {
        updateControlBarBackgroundImage(image: readControlBarBackgroundImage())
        updateControlBarBackgroundImageOpacity()
    }

    func updateControlBarBackgroundImageOpacity() {
        controlBar.backgroundImageOpacity = database.quickButtonsGeneral.backgroundImageOpacity
    }

    func updateControlBarBackgroundImage(image: UIImage?) {
        guard let image else {
            controlBar.backgroundImage = nil
            return
        }
        let quickButtons = database.quickButtonsGeneral
        let x = image.size.width * quickButtons.backgroundImageCropX
        let y = image.size.height * quickButtons.backgroundImageCropY
        let width = image.size.width * quickButtons.backgroundImageCropWidth
        let height = image.size.height * quickButtons.backgroundImageCropHeight
        guard width > 0, height > 0 else {
            controlBar.backgroundImage = image
            return
        }
        let scale = min(1, 1024 / max(width, height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: .init(width: width * scale, height: height * scale),
                                               format: format)
        controlBar.backgroundImage = renderer.image { _ in
            image.draw(in: .init(x: -x * scale,
                                 y: -y * scale,
                                 width: image.size.width * scale,
                                 height: image.size.height * scale))
        }
    }

    func deleteControlBarBackgroundImage() {
        try? FileManager.default.removeItem(at: controlBarBackgroundImagePath)
        controlBar.backgroundImage = nil
    }
}
