import AVFAudio
import SwiftUI

private var loadedImages: [UUID: Image] = [:]

private func loadImage(model: Model, imageId: UUID) -> Image? {
    if let image = loadedImages[imageId] {
        return image
    }
    var image: Image?
    if let bundledImage = model.database.alertsMediaGallery!.bundledImages
        .first(where: { $0.id == imageId })
    {
        image = Image("Alerts.bundle/\(bundledImage.name).gif")
    } else if let data = model.alertMediaStorage.tryRead(id: imageId) {
        if let uiImage = UIImage(data: data) {
            image = Image(uiImage: uiImage)
        }
    }
    if let image {
        loadedImages[imageId] = image
    }
    return nil
}

private struct CustomImageView: View {
    @EnvironmentObject var model: Model
    var media: SettingsAlertsMediaGalleryItem
    @State var showPicker = false
    @State var image: Image?

    private func onUrl(url: URL) {
        model.alertMediaStorage.add(id: media.id, url: url)
        loadedImages.removeValue(forKey: media.id)
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
                            image
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
    var alert: SettingsWidgetAlertsTwitchAlert
    @Binding var imageId: UUID

    var body: some View {
        Form {
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
                        imageId = alert.imageId
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
    @Binding var imageId: UUID

    var body: some View {
        Form {
            Section {
                Picker("", selection: $imageId) {
                    ForEach(model.getAllAlertImages()) { image in
                        HStack {
                            Text(image.name)
                            Spacer()
                            if let image = loadImage(model: model, imageId: image.id) {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 50)
                            } else {
                                Image(systemName: "photo")
                            }
                        }
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
                NavigationLink(destination: ImageGalleryView(alert: alert, imageId: $imageId)) {
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
