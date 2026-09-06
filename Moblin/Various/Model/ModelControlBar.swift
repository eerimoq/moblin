import Foundation
import SwiftUI

let controlBarBackgroundImagePath = URL.documentsDirectory
    .appending(component: "controlBarBackgroundImage.img")

extension Model {
    func saveControlBarBackgroundImage(data: Data) -> UIImage? {
        guard let original = UIImage(data: data) else {
            return nil
        }
        let image = downscaleControlBarBackgroundImage(image: original) ?? original
        writeControlBarBackgroundImage(image: image)
        let quickButtons = database.quickButtonsGeneral
        quickButtons.backgroundImageCropX = 0
        quickButtons.backgroundImageCropY = 0
        quickButtons.backgroundImageCropWidth = 1
        quickButtons.backgroundImageCropHeight = 1
        updateControlBarBackgroundImage(image: image)
        return image
    }

    func readControlBarBackgroundImage() -> UIImage? {
        guard let data = try? Data(contentsOf: controlBarBackgroundImagePath) else {
            return nil
        }
        return UIImage(data: data)
    }

    private func writeControlBarBackgroundImage(image: UIImage) {
        try? image.jpegData(compressionQuality: 0.9)?.write(to: controlBarBackgroundImagePath)
    }

    private func downscaleControlBarBackgroundImage(image: UIImage) -> UIImage? {
        let scale = 2048 / max(image.size.width, image.size.height)
        guard scale < 1 else {
            return nil
        }
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
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
