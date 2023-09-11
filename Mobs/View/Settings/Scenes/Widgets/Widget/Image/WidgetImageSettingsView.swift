import SwiftUI
import PhotosUI

struct WidgetImageSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    @State var selectedImageItem: PhotosPickerItem? = nil

    var body: some View {
        Section(widget.type) {
            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                if let data = model.imageStorage.read(id: widget.id) {
                    Image(uiImage: UIImage(data: data)!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 1920 / 6, height: 1080 / 6)
                }
                Text("Select image")
            }
            .onChange(of: selectedImageItem) { imageItem in
                imageItem!.loadTransferable(type: Data.self) { result in
                    switch result {
                    case .success(let data?):
                        model.imageStorage.write(id: widget.id, data: data)
                        DispatchQueue.main.async {
                            model.sceneUpdated()
                        }
                    case .success(nil):
                        logger.error("widget: image is nil")
                    case .failure(let error):
                        logger.error("widget: image error: \(error)")
                    }
                }
            }
        }
    }
}
