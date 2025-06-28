import Foundation
import UIKit

private let stealthModeImagePath = URL.documentsDirectory.appending(component: "stealthModeImage.img")

extension Model {
    func toggleStealthMode() {
        showStealthMode.toggle()
    }

    func saveStealthModeImage(data: Data) {
        try? data.write(to: stealthModeImagePath)
    }

    func loadStealthModeImage() {
        guard let data = try? Data(contentsOf: stealthModeImagePath) else {
            return
        }
        stealthMode.image = UIImage(data: data)
    }

    func deleteStealthModeImage() {
        try? FileManager.default.removeItem(at: stealthModeImagePath)
    }
}
