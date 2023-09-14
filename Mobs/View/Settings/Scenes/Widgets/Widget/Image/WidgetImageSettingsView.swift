import PhotosUI
import SwiftUI

struct WidgetImageSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    @State var selectedImageItem: PhotosPickerItem?

    var body: some View {
        Section(widget.type.rawValue) {
            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                if let data = model.imageStorage.tryRead(id: widget.id) {
                    Image(uiImage: UIImage(data: data)!)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 1920 / 6, height: 1080 / 6)
                }
                HStack {
                    Spacer()
                    Text("Select image")
                    Spacer()
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
        }
    }
}
