import PhotosUI
import SwiftUI

struct WidgetImagePickerView: View {
    let model: Model
    let widget: SettingsWidget
    @Binding var image: UIImage?
    let sizeScale: Double
    @State private var selectedImageItem: PhotosPickerItem?

    func loadImage() {
        if let data = model.imageStorage.tryRead(id: widget.id) {
            image = UIImage(data: data)
        } else {
            image = nil
        }
    }

    var body: some View {
        Section {
            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                if let image {
                    HCenter {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 1920 / sizeScale, height: 1080 / sizeScale)
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
                            loadImage()
                        }
                    case .success(nil):
                        logger.error("widget: image is nil")
                    case let .failure(error):
                        logger.error("widget: image error: \(error)")
                    }
                }
            }
            .onAppear {
                model.checkPhotoLibraryAuthorization()
                if image == nil {
                    loadImage()
                }
            }
        }
    }
}

struct WidgetImageSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget
    @State private var image: UIImage?

    var body: some View {
        WidgetImagePickerView(model: model, widget: widget, image: $image, sizeScale: 6)
        WidgetEffectsView(widget: widget)
    }
}
