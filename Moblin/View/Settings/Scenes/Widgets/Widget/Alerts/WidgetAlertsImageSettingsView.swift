import AVFAudio
import SwiftUI

private var loadedImages: [UUID: UIImage] = [:]

private func loadImage(model: Model, imageId: UUID) -> UIImage? {
    if let image = loadedImages[imageId] {
        return image
    }
    var image: UIImage?
    if let bundledImage = model.database.alertsMediaGallery!.bundledImages
        .first(where: { $0.id == imageId })
    {
        if let path = Bundle.main.path(forResource: "Alerts.bundle/\(bundledImage.name)", ofType: "gif") {
            image = UIImage(contentsOfFile: path)
        }
    } else if let data = model.alertMediaStorage.tryRead(id: imageId) {
        image = UIImage(data: data)
    }
    if let image {
        loadedImages[imageId] = image
    }
    return image
}

private struct CustomImageView: View {
    @EnvironmentObject var model: Model
    var media: SettingsAlertsMediaGalleryItem
    @State var showPicker = false
    @State var image: UIImage?

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
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "an image"))
            }
        }
        .navigationTitle("My images")
        .toolbar {
            SettingsToolbar()
        }
    }
}

struct AlertImageSelectorView: View {
    @EnvironmentObject var model: Model
    var alert: SettingsWidgetAlertsTwitchAlert
    @Binding var imageId: UUID
    @State var loopCount: Float

    var body: some View {
        Form {
            Section {
                Picker("", selection: $imageId) {
                    ForEach(model.getAllAlertImages()) { image in
                        HStack {
                            Text(image.name)
                            Spacer()
                            if let image = loadImage(model: model, imageId: image.id) {
                                Image(uiImage: image)
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
                HStack {
                    Text("Repeat")
                    Slider(
                        value: $loopCount,
                        in: 1 ... 10,
                        step: 1,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            alert.imageLoopCount = Int(loopCount)
                            model.updateAlertsSettings()
                        }
                    )
                    Text(String(Int(loopCount)))
                        .frame(width: 25)
                }
            } footer: {
                Text("Number of times the GIF will be played each alert.")
            }
            Section {
                NavigationLink(destination: ImageGalleryView(alert: alert, imageId: $imageId)) {
                    Text("My images")
                }
            }
        }
        .navigationTitle("Image")
        .toolbar {
            SettingsToolbar()
        }
    }
}
