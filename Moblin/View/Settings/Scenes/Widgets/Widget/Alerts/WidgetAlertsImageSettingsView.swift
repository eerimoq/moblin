import AVFAudio
import PhotosUI
import SDWebImageSwiftUI
import SwiftUI

private var loadedImages: [UUID: Data] = [:]

func loadAlertImage(model: Model, imageId: UUID) -> Data? {
    if let image = loadedImages[imageId] {
        return image
    }
    var image: Data?
    if let bundledImage = model.database.alertsMediaGallery.bundledImages
        .first(where: { $0.id == imageId })
    {
        if let path = Bundle.main.path(forResource: "Alerts.bundle/\(bundledImage.name)", ofType: "gif") {
            image = try? Data(contentsOf: URL(filePath: path))
        }
    } else {
        image = model.alertMediaStorage.tryRead(id: imageId)
    }
    if let image {
        loadedImages[imageId] = image
    }
    return image
}

private struct CustomImageView: View {
    @EnvironmentObject var model: Model
    let media: SettingsAlertsMediaGalleryItem
    @State var showPicker = false
    @State var image: Data?

    private func onUrl(url: URL) {
        model.alertMediaStorage.add(id: media.id, url: url)
        loadedImages.removeValue(forKey: media.id)
        image = loadAlertImage(model: model, imageId: media.id)
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
                    HCenter {
                        if let image {
                            AnimatedImage(data: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 1920 / 6, height: 1080 / 6)
                        } else {
                            Text("Select image")
                        }
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
    }
}

private struct ImageGalleryView: View {
    @EnvironmentObject var model: Model
    let alert: SettingsWidgetAlertsAlert
    @Binding var imageId: UUID

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.alertsMediaGallery.customImages) { image in
                        NavigationLink {
                            CustomImageView(
                                media: image,
                                image: loadAlertImage(model: model, imageId: image.id)
                            )
                        } label: {
                            Text(image.name)
                        }
                    }
                    .onDelete { offsets in
                        model.database.alertsMediaGallery.customImages.remove(atOffsets: offsets)
                        model.fixAlertMedias()
                        imageId = alert.imageId
                    }
                }
                TextButtonView("Add") {
                    let image = SettingsAlertsMediaGalleryItem(name: "My image")
                    model.database.alertsMediaGallery.customImages.append(image)
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "an image"))
            }
        }
        .navigationTitle("My images")
    }
}

struct AlertImageSelectorView: View {
    @EnvironmentObject var model: Model
    let alert: SettingsWidgetAlertsAlert
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
                            if let image = loadAlertImage(model: model, imageId: image.id) {
                                AnimatedImage(data: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 90, height: 50)
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
                        label: {
                            EmptyView()
                        },
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
                NavigationLink {
                    ImageGalleryView(alert: alert, imageId: $imageId)
                } label: {
                    Text("My images")
                }
            }
        }
        .navigationTitle("Image")
    }
}
