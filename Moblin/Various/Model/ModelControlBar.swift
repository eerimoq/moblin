import Foundation
import SwiftUI

let controlBarBackgroundImagePath = URL.documentsDirectory
    .appending(component: "controlBarBackgroundImage.img")

func quickButtonNameMatchesFilter(name: String, filter: String) -> Bool {
    let filterWords = filter.lowercased().split(whereSeparator: \.isWhitespace)
    let nameWords = name.lowercased().split(whereSeparator: \.isWhitespace)
    guard nameWords.count >= filterWords.count else {
        return false
    }
    return (0 ... nameWords.count - filterWords.count).contains { start in
        zip(nameWords[start...], filterWords).allSatisfy { $0.hasPrefix($1) }
    }
}

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

    func controlBarDoubleTapped() {
        guard !quickButtonsFilter.filtering else {
            return
        }
        quickButtonsFilter.filter = ""
        quickButtons.scrollToButtonId = nil
        updateFilteredQuickButtonPairs()
        quickButtonsFilter.filtering = true
    }

    func stopFilteringQuickButtons() {
        quickButtonsFilter.filtering = false
        quickButtonsFilter.presentingDialog = false
    }

    func quickButtonsFilterPresentingDialog() {
        guard quickButtonsFilter.filtering else {
            return
        }
        quickButtonsFilter.presentingDialog = true
    }

    func quickButtonsFilterFocusLost() {
        guard !quickButtonsFilter.presentingDialog else {
            return
        }
        stopFilteringQuickButtons()
    }

    func stopFilteringQuickButtons(showButton button: SettingsQuickButton) {
        guard quickButtonsFilter.filtering else {
            return
        }
        stopFilteringQuickButtons()
        quickButtonsPages.page = button.page
        quickButtonsPages.activePage = button.page
        if database.quickButtonsGeneral.enableScroll {
            quickButtons.scrollToButtonId = button.id
        }
    }

    func takeQuickButtonToScrollTo(pairs: [QuickButtonPair]) -> UUID? {
        guard let buttonId = quickButtons.scrollToButtonId,
              quickButtons.pairs.contains(pairs),
              pairs.contains(where: { $0.first.id == buttonId || $0.second?.id == buttonId })
        else {
            return nil
        }
        quickButtons.scrollToButtonId = nil
        return buttonId
    }

    func deleteControlBarBackgroundImage() {
        try? FileManager.default.removeItem(at: controlBarBackgroundImagePath)
        controlBar.backgroundImage = nil
    }
}
