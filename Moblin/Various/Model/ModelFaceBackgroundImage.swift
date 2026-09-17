import Foundation
import SwiftUI

let faceBackgroundImagePath = URL.documentsDirectory.appending(component: "faceBackgroundImage.img")

extension Model {
    nonisolated func saveFaceBackgroundImage(data: Data) {
        try? data.write(to: faceBackgroundImagePath)
    }

    func loadFaceBackgroundImage() {
        faceBackgroundImage = readFaceBackgroundImage()
        updateFaceFilterSettings()
    }

    private func readFaceBackgroundImage() -> CIImage? {
        guard let data = try? Data(contentsOf: faceBackgroundImagePath),
              let cgImage = UIImage(data: data)?.cgImage
        else {
            return nil
        }
        return CIImage(cgImage: cgImage)
    }
}
