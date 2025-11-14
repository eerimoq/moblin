import PhotosUI
import SwiftUI

private struct QuickButtonStealthModeView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stealthMode: StealthMode
    @State var selectedImageItem: PhotosPickerItem?

    var body: some View {
        Section {
            PhotosPicker(selection: $selectedImageItem, matching: .images) {
                if let image = stealthMode.image {
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
                            self.stealthMode.image = UIImage(data: data)
                        }
                    default:
                        break
                    }
                }
            }
            if stealthMode.image != nil {
                TextButtonView("Delete image") {
                    stealthMode.image = nil
                    model.deleteStealthModeImage()
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
                TextButtonView("Reset") {
                    button.color = defaultQuickButtonColor.color()
                    onColorChange(color: button.color)
                }
            } header: {
                Text("Color")
            }
            if #available(iOS 17, *) {
                Section {
                    Picker(selection: $button.page) {
                        ForEach(1 ... controlBarPages, id: \.self) { page in
                            Text(String(page))
                                .tag(page)
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
                QuickButtonStealthModeView(stealthMode: model.stealthMode)
            default:
                EmptyView()
            }
            if shortcut {
                Section {
                    NavigationLink {
                        QuickButtonsSettingsView(model: model)
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
