import Foundation
import SwiftUI

private let faceBackgroundImagePath = URL.documentsDirectory.appending(component: "faceBackgroundImage.img")

extension Model {
    nonisolated func saveFaceBackgroundImage(data: Data) {
        try? data.write(to: faceBackgroundImagePath)
    }

    func loadFaceBackgroundImage() {
        guard let data = try? Data(contentsOf: faceBackgroundImagePath) else {
            return
        }
        guard let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else {
            return
        }
        faceBackgroundImage = CIImage(cgImage: cgImage)
    }

    func deleteFaceBackgroundImage() {
        try? FileManager.default.removeItem(at: faceBackgroundImagePath)
    }
}
