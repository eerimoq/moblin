import PhotosUI
import SwiftUI

struct WidgetImageSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget
    @State var selectedImageItem: PhotosPickerItem?

    func loadImage() -> UIImage? {
        if let data = model.imageStorage.tryRead(id: widget.id) {
            return UIImage(data: data)
        } else {
            return nil
        }
    }

    var body: some View {
        Section {
            let image = loadImage()
            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                if let image {
                    HCenter {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 1920 / 6, height: 1080 / 6)
                    }
                } else {
                    HCenter {
                        Text("Select image")
                    }
                }
            }
            .onChange(of: selectedImageItem) { imageItem in
                imageItem?.loadTransferable(type: Data.self) { result in
                    switch result {
                    case let .success(data?):
                        model.imageStorage.write(id: widget.id, data: data)
                        DispatchQueue.main.async {
                            model.sceneUpdated(imageEffectChanged: true)
                            model.objectWillChange.send()
                        }
                    case .success(nil):
                        logger.error("widget: image is nil")
                    case let .failure(error):
                        logger.error("widget: image error: \(error)")
                    }
                }
            }
        }
        .onAppear {
            model.checkPhotoLibraryAuthorization()
        }
        WidgetEffectsView(widget: widget)
    }
}
