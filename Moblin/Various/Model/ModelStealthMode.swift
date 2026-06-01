import Foundation
import SwiftUI

let stealthModeImagePath = URL.documentsDirectory.appending(component: "stealthModeImage.img")

extension Model {
    func setStealthMode(on: Bool) {
        showStealthMode = on
        remoteControlStateChanged(state: .init(stealthMode: on))
    }

    func toggleStealthMode() {
        setStealthMode(on: !showStealthMode)
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
