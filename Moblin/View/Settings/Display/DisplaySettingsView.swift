import PhotosUI
import SwiftUI

private struct BackgroundImageCropView: View {
    let model: Model
    @ObservedObject var quickButtons: SettingsQuickButtons
    let image: UIImage
    @State private var position: CGPoint = .init(x: 100, y: 100)
    @State private var positionOffset: CGSize = .init(width: 0, height: 0)
    @State private var positionAnchorPoint: AnchorPoint?
    @State private var latestImageUpdateTime: ContinuousClock.Instant = .now

    private func updatePositionAnchorPoint(location: CGPoint, size: CGSize) {
        if positionAnchorPoint == nil {
            (positionAnchorPoint, positionOffset) = calculatePositioningAnchorPoint(
                location,
                size,
                quickButtons.backgroundImageCropX,
                quickButtons.backgroundImageCropY,
                quickButtons.backgroundImageCropWidth,
                quickButtons.backgroundImageCropHeight
            )
        }
    }

    private func createPositionRectangle(size: CGSize) -> CGRect {
        let (xTopLeft, yTopLeft, xBottomRight, yBottomRight) = calculatePositioningRectangle(
            positionAnchorPoint,
            quickButtons.backgroundImageCropX,
            quickButtons.backgroundImageCropY,
            quickButtons.backgroundImageCropWidth,
            quickButtons.backgroundImageCropHeight,
            position,
            size,
            positionOffset
        )
        quickButtons.backgroundImageCropX = xTopLeft
        quickButtons.backgroundImageCropY = yTopLeft
        quickButtons.backgroundImageCropWidth = xBottomRight - xTopLeft
        quickButtons.backgroundImageCropHeight = yBottomRight - yTopLeft
        return CGRect(
            x: CGFloat(quickButtons.backgroundImageCropX) * size.width,
            y: CGFloat(quickButtons.backgroundImageCropY) * size.height,
            width: CGFloat(quickButtons.backgroundImageCropWidth) * size.width,
            height: CGFloat(quickButtons.backgroundImageCropHeight) * size.height
        )
    }

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
            GeometryReader { reader in
                Canvas { context, size in
                    drawPositioningRectangle(context, createPositionRectangle(size: size))
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            position = value.location
                            let size = reader.size
                            updatePositionAnchorPoint(location: position, size: size)
                            let now = ContinuousClock.now
                            if latestImageUpdateTime.duration(to: now) > .milliseconds(100) {
                                latestImageUpdateTime = now
                                model.updateControlBarBackgroundImage(image: image)
                            }
                        }
                        .onEnded { _ in
                            positionAnchorPoint = nil
                            model.updateControlBarBackgroundImage(image: image)
                        }
                )
            }
        }
    }
}

private struct BackgroundImageSettingsView: View {
    let model: Model
    @ObservedObject var quickButtons: SettingsQuickButtons
    @State private var image: UIImage?
    @State private var presentingPicker: Bool = false
    @State private var selectedImageItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section {
                if let image {
                    BackgroundImageCropView(model: model, quickButtons: quickButtons, image: image)
                }
                TextButtonView("Select image") {
                    presentingPicker = true
                }
                .photosPicker(
                    isPresented: $presentingPicker,
                    selection: $selectedImageItem,
                    matching: .images
                )
                .onChange(of: selectedImageItem) { imageItem in
                    selectedImageItem = nil
                    imageItem?.loadTransferable(type: Data.self) { result in
                        switch result {
                        case let .success(data?):
                            DispatchQueue.main.async {
                                image = model.saveControlBarBackgroundImage(data: data)
                            }
                        default:
                            break
                        }
                    }
                }
                if image != nil {
                    TextButtonView("Delete image") {
                        image = nil
                        model.deleteControlBarBackgroundImage()
                    }
                    .tint(.red)
                }
            }
            .onAppear {
                model.checkPhotoLibraryAuthorization()
                image = model.readControlBarBackgroundImage()
            }
            if image != nil {
                Section {
                    HStack {
                        Text("Opacity")
                        Slider(value: $quickButtons.backgroundImageOpacity, in: 0 ... 1) {
                            Text("")
                        }
                        .onChange(of: quickButtons.backgroundImageOpacity) { _ in
                            model.updateControlBarBackgroundImageOpacity()
                        }
                    }
                }
            }
        }
        .navigationTitle("Background")
    }
}

private struct ExternalDisplayContentView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Picker("External monitor content", selection: $database.externalDisplayContent) {
            ForEach(SettingsExternalDisplayContent.allCases, id: \.self) {
                Text($0.toString())
            }
        }
        .onChange(of: database.externalDisplayContent) { _ in
            model.setExternalDisplayContent()
        }
    }
}

struct DisplaySettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    QuickButtonsSettingsView(model: model, showAll: true)
                } label: {
                    Text("Quick buttons")
                }
                NavigationLink {
                    StreamButtonsSettingsView(database: database)
                } label: {
                    Text("Stream button")
                }
                NavigationLink {
                    BackgroundImageSettingsView(
                        model: model,
                        quickButtons: model.database.quickButtonsGeneral
                    )
                } label: {
                    Text("Background")
                }
            } header: {
                Text("Control bar")
            }
            Section {
                Toggle("Big buttons", isOn: $database.bigButtons)
                Toggle("Big audio level meter", isOn: $database.bigAudioLevelMeter)
                Toggle("Vertical buttons", isOn: $database.verticalButtons)
                if database.showAllSettings {
                    NavigationLink {
                        LocalOverlaysSettingsView(show: database.show)
                    } label: {
                        Text("Local overlays")
                    }
                    ExternalDisplayContentView(database: database)
                    NavigationLink {
                        LocalOverlaysNetworkInterfaceNamesSettingsView(database: database)
                    } label: {
                        Text("Network interface names")
                    }
                    Toggle("Low bitrate warning", isOn: $database.lowBitrateWarning)
                    Toggle("Recording confirmations", isOn: $database.startStopRecordingConfirmations)
                }
            } header: {
                Text("General")
            }
            Section {
                Toggle("Vibrate", isOn: $database.vibrate)
                    .onChange(of: database.vibrate) { _ in
                        model.setAllowHapticsAndSystemSoundsDuringRecording()
                    }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Enable to vibrate the device when the following toasts appear:")
                    Text("")
                    Text("• \(fffffMessage)")
                    Text("• \(failedToConnectMessage("Main"))")
                    Text("• \(formatWarning(lowBitrateMessage))")
                    Text("• \(formatWarning(lowBatteryMessage))")
                    Text("• \(formatWarning(flameRedMessage))")
                    Text("")
                    Text("Make sure silent mode is off for vibrations to work.")
                }
            }
            Section {
                Toggle("Connection status sound", isOn: $database.show.connectionStatusSound)
            } footer: {
                VStack(alignment: .leading) {
                    Text("Enable to play a short sound when the stream fails to connect.")
                }
            }

            if database.showAllSettings {
                if !isMac() {
                    Section {
                        Toggle(isOn: Binding(get: {
                            database.portrait
                        }, set: { _ in
                            model.setDisplayPortrait(portrait: !database.portrait)
                        })) {
                            Text("Portrait")
                        }
                        HStack {
                            Text("Video position")
                            Slider(value: $model.portraitVideoOffsetFromTop, in: 0 ... 1) {
                                Text("")
                            }
                        }
                        .onChange(of: model.portraitVideoOffsetFromTop) {
                            database.portraitVideoOffsetFromTop = $0
                        }
                    } footer: {
                        VStack(alignment: .leading) {
                            Text("Useful when using an external camera and a portrait phone holder.")
                            Text("")
                            Text(
                                "To stream in portrait, enable Settings → Streams → \(model.stream.name) → Portrait."
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Display")
    }
}
