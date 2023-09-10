import SwiftUI
import PhotosUI

struct WidgetImageSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    @State var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        Section(widget.type) {
            PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
                Text("Select an image")
            }
            .onChange(of: selectedItems) { items in
                items[0].loadTransferable(type: Image.self) { result in
                    switch result {
                    case .success(let image?):
                        print("success", image)
                    case .success(nil):
                        print("nil")
                    case .failure(let error):
                        print("error", error)
                    }
                }
            }
        }
    }
}
