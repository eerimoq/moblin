import AVFAudio
import SwiftUI
import UniformTypeIdentifiers

private func loadImage(model: Model, imageId: UUID) -> UIImage? {
    if let data = model.alertMediaStorage.tryRead(id: imageId) {
        return UIImage(data: data)!
    } else {
        return nil
    }
}

private struct CustomImageView: View {
    @EnvironmentObject var model: Model
    var media: SettingsAlertsMediaGalleryItem
    @State var showPicker = false
    @State var image: UIImage?

    private func onUrl(url: URL) {
        model.alertMediaStorage.add(id: media.id, url: url)
        image = loadImage(model: model, imageId: media.id)
        model.updateAlertsSettings()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Name"),
                    value: media.name,
                    onSubmit: {
                        media.name = $0
                    }
                )
            }
            Section {
                Button {
                    showPicker = true
                    model.onDocumentPickerUrl = onUrl
                } label: {
                    HStack {
                        Spacer()
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 1920 / 6, height: 1080 / 6)
                        } else {
                            Text("Select image")
                        }
                        Spacer()
                    }
                }
                .sheet(isPresented: $showPicker) {
                    AlertPickerView(type: .gif)
                }
            } footer: {
                Text("Only GIF:s are supported.")
            }
        }
        .navigationTitle("Image")
        .toolbar {
            SettingsToolbar()
        }
    }
}

private struct ImageGalleryView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.alertsMediaGallery!.bundledImages) { image in
                        Text(image.name)
                    }
                }
            } header: {
                Text("Bundled")
            }
            Section {
                List {
                    ForEach(model.database.alertsMediaGallery!.customImages) { image in
                        NavigationLink(destination: CustomImageView(
                            media: image,
                            image: loadImage(model: model, imageId: image.id)
                        )) {
                            Text(image.name)
                        }
                    }
                    .onDelete(perform: { offsets in
                        model.database.alertsMediaGallery!.customImages.remove(atOffsets: offsets)
                        model.fixAlertMedias()
                    })
                }
                Button(action: {
                    let image = SettingsAlertsMediaGalleryItem(name: "My image")
                    model.database.alertsMediaGallery!.customImages.append(image)
                    model.objectWillChange.send()
                }, label: {
                    HStack {
                        Spacer()
                        Text("Add")
                        Spacer()
                    }
                })
            } header: {
                Text("My images")
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "an image"))
            }
        }
        .navigationTitle("Gallery")
        .toolbar {
            SettingsToolbar()
        }
    }
}

struct AlertImageSelectorView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @State var imageId: UUID

    var body: some View {
        Form {
            Section {
                Picker("", selection: $imageId) {
                    ForEach(model.getAllAlertImages()) {
                        Text($0.name)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: imageId) {
                    alert.imageId = $0
                    model.updateAlertsSettings()
                }
            }
            Section {
                NavigationLink(destination: ImageGalleryView()) {
                    Text("Gallery")
                }
            }
        }
        .navigationTitle("Image")
        .toolbar {
            SettingsToolbar()
        }
    }
}
