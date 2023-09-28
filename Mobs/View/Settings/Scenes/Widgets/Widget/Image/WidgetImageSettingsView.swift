import PhotosUI
import SwiftUI

func formatInt(_ value: CGFloat) -> String {
    return String(format: "%d", Int(value))
}

struct WidgetImageSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    @State var selectedImageItem: PhotosPickerItem?

    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
        model.checkDeviceAuthorization()
    }

    func loadImage() -> UIImage? {
        if let data = model.imageStorage.tryRead(id: widget.id) {
            return UIImage(data: data)!
        } else {
            return nil
        }
    }

    var body: some View {
        Section(widget.type.rawValue) {
            let image = loadImage()
            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                if let image {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 1920 / 6, height: 1080 / 6)
                        Spacer()
                    }
                } else {
                    HStack {
                        Spacer()
                        Text("Select image")
                        Spacer()
                    }
                }
            }
            .onChange(of: selectedImageItem) { imageItem in
                imageItem!.loadTransferable(type: Data.self) { result in
                    switch result {
                    case let .success(data?):
                        model.imageStorage.write(id: widget.id, data: data)
                        DispatchQueue.main.async {
                            model.sceneUpdated(imageEffectChanged: true)
                        }
                    case .success(nil):
                        logger.error("widget: image is nil")
                    case let .failure(error):
                        logger.error("widget: image error: \(error)")
                    }
                }
            }
            if let image {
                HStack {
                    TextItemView(
                        name: "Dimensions",
                        value: "\(formatInt(image.size.width))x\(formatInt(image.size.height))"
                    )
                }
            }
        }
    }
}
