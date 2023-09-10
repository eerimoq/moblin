import SwiftUI
import PhotosUI

struct WidgetImageSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    @State var selectedImageItem: PhotosPickerItem? = nil

    var body: some View {
        Section(widget.type) {
            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                Text("Select image")
            }
            .onChange(of: selectedImageItem) { imageItem in
                imageItem!.loadTransferable(type: Data.self) { result in
                    switch result {
                    case .success(let data?):
                        logger.info("widget: image success: \(data)")
                        model.imageStorage.write(name: "1", data: data)
                    case .success(nil):
                        logger.error("widget: image nil")
                    case .failure(let error):
                        logger.error("widget: image error: \(error)")
                    }
                }
            }
        }
    }
}
