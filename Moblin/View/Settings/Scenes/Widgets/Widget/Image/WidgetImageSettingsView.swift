import PhotosUI
import SwiftUI

struct WidgetImageSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var selectedImageItem: PhotosPickerItem?

    func loadImage() -> UIImage? {
        if let data = model.imageStorage.tryRead(id: widget.id) {
            return UIImage(data: data)!
        } else {
            return nil
        }
    }

    var body: some View {
        Section(widget.type.toString()) {
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
                        name: String(localized: "Dimensions"),
                        value: "\(formatAsInt(image.size.width))x\(formatAsInt(image.size.height))"
                    )
                }
            }
        }
        .onAppear {
            model.checkDeviceAuthorization()
        }
    }
}
