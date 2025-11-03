import PhotosUI
import SwiftUI

struct WidgetWizardImageSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool
    @State var selectedImageItem: PhotosPickerItem?
    @State var image: UIImage?

    func loadImage() {
        if let data = model.imageStorage.tryRead(id: widget.id) {
            image = UIImage(data: data)
        } else {
            image = nil
        }
    }

    var body: some View {
        Form {
            Section {
                PhotosPicker(selection: $selectedImageItem, matching: .images) {
                    if let image {
                        HCenter {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 1920 / 5, height: 1080 / 5)
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
            }
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(image == nil)
        }
        .navigationTitle("Basic \(createWidgetWizard.type.toString()) widget settings")
        .toolbar {
            CreateWidgetWizardToolbar(presentingCreateWizard: $presentingCreateWizard)
        }
    }
}
