import PhotosUI
import SwiftUI

private struct StealthModeView: View {
    @EnvironmentObject var model: Model
    @State var selectedImageItem: PhotosPickerItem?

    var body: some View {
        Section {
            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                if let image = model.stealthModeImage {
                    HCenter {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                } else {
                    HCenter {
                        Text("Select image")
                    }
                }
            }
            .onChange(of: selectedImageItem) { imageItem in
                selectedImageItem = nil
                imageItem?.loadTransferable(type: Data.self) { result in
                    switch result {
                    case let .success(data?):
                        model.saveStealthModeImage(data: data)
                        DispatchQueue.main.async {
                            self.model.stealthModeImage = UIImage(data: data)
                        }
                    default:
                        break
                    }
                }
            }
            if model.stealthModeImage != nil {
                Button {
                    model.stealthModeImage = nil
                    model.deleteStealthModeImage()
                } label: {
                    HCenter {
                        Text("Delete image")
                    }
                }
            }
        } footer: {
            Text("Show selected image instead of a black screen.")
        }
        .onAppear {
            model.checkPhotoLibraryAuthorization()
        }
    }
}

struct QuickButtonsButtonSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var quickButtons: SettingsQuickButtons
    @ObservedObject var button: SettingsQuickButton
    let shortcut: Bool

    private func onColorChange(color: Color) {
        guard let color = color.toRgb() else {
            return
        }
        button.backgroundColor = color
        model.updateQuickButtonStates()
    }

    var body: some View {
        Form {
            Section {
                ColorPicker("Background", selection: $button.color, supportsOpacity: false)
                    .onChange(of: button.color) { _ in
                        onColorChange(color: button.color)
                    }
                Button {
                    button.color = defaultQuickButtonColor.color()
                    onColorChange(color: button.color)
                } label: {
                    HCenter {
                        Text("Reset")
                    }
                }
            } header: {
                Text("Color")
            }
            if #available(iOS 17, *) {
                Section {
                    Picker(selection: $button.page) {
                        ForEach(1 ... controlBarPages, id: \.self) { page in
                            Text(String(page))
                                .tag(page as Int?)
                        }
                    } label: {
                        Text("Page")
                    }
                    .onChange(of: button.page) { _ in
                        model.updateQuickButtonStates()
                    }
                }
            }
            switch button.type {
            case .blackScreen:
                StealthModeView()
            default:
                EmptyView()
            }
            if shortcut {
                Section {
                    NavigationLink {
                        QuickButtonsSettingsView()
                    } label: {
                        Label("Quick buttons", systemImage: "rectangle.inset.topright.fill")
                    }
                } header: {
                    Text("Shortcut")
                }
            }
        }
        .navigationTitle(button.name)
    }
}
