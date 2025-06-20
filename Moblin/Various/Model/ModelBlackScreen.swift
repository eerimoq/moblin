import Foundation
import UIKit

private let blackScreenImagePath = URL.documentsDirectory.appending(component: "blackScreenImage.img")

extension Model {
    func toggleBlackScreen() {
        blackScreen.toggle()
    }

    func saveBlackScreenImage(data: Data) {
        try? data.write(to: blackScreenImagePath)
    }

    func loadBlackScreenImage() {
        guard let data = try? Data(contentsOf: blackScreenImagePath) else {
            return
        }
        blackScreenImage = UIImage(data: data)
    }

    func deleteBlackScreenImage() {
        try? FileManager.default.removeItem(at: blackScreenImagePath)
    }
}
