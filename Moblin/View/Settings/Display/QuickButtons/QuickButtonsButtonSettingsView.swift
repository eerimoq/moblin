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

private struct PositionButtonView: View {
    let image: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: image)
        }
    }
}

struct QuickButtonsButtonSettingsView: View {
    let model: Model
    @ObservedObject var orientation: Orientation
    @ObservedObject var quickButtonsSettings: SettingsQuickButtons
    @ObservedObject var button: SettingsQuickButton

    private func onColorChange(color: Color) {
        guard let color = color.toRgb() else {
            return
        }
        button.backgroundColor = color
        model.updateQuickButtonStates()
    }

    private func moveUp() {
        var otherButton: SettingsQuickButton?
        let pairs = model.getQuickButtonPairs(page: button.page)
        for (pairIndex, pair) in pairs.enumerated() {
            let otherPair = pairs[(pairIndex + 1) % pairs.count]
            if pair.first.button.id == button.id {
                if quickButtonsSettings.twoColumns {
                    otherButton = otherPair.first.button
                } else {
                    otherButton = otherPair.second?.button
                    if otherButton == nil {
                        otherButton = otherPair.first.button
                    }
                }
                break
            } else if pair.second?.button.id == button.id {
                if quickButtonsSettings.twoColumns {
                    otherButton = otherPair.second?.button
                    if otherButton == nil {
                        otherButton = pairs[0].second?.button
                    }
                } else {
                    otherButton = pair.first.button
                }
                break
            }
        }
        swapButtons(firstButton: button, secondButton: otherButton)
    }

    private func moveDown() {
        var otherButton: SettingsQuickButton?
        let pairs = model.getQuickButtonPairs(page: button.page)
        for (pairIndex, pair) in pairs.enumerated() {
            let otherPair = pairs[(pairs.count + pairIndex - 1) % pairs.count]
            if pair.first.button.id == button.id {
                if quickButtonsSettings.twoColumns {
                    otherButton = otherPair.first.button
                } else {
                    otherButton = pair.second?.button
                    if otherButton == nil {
                        otherButton = otherPair.first.button
                    }
                }
                break
            } else if pair.second?.button.id == button.id {
                if quickButtonsSettings.twoColumns {
                    otherButton = otherPair.second?.button
                    if otherButton == nil {
                        otherButton = pairs[pairs.count - 2].second?.button
                    }
                } else {
                    otherButton = otherPair.first.button
                }
                break
            }
        }
        swapButtons(firstButton: button, secondButton: otherButton)
    }

    private func moveLeftRight() {
        guard let pair = model.getQuickButtonPairs(page: button.page).first(where: {
            $0.first.button.id == button.id || $0.second?.button.id == button.id
        }) else {
            return
        }
        swapButtons(firstButton: pair.first.button, secondButton: pair.second?.button)
    }

    private func swapButtons(firstButton: SettingsQuickButton?, secondButton: SettingsQuickButton?) {
        let database = model.database
        guard let firstIndex = database.quickButtons.firstIndex(where: { $0.id == firstButton?.id }),
              let secondIndex = database.quickButtons.firstIndex(where: { $0.id == secondButton?.id })
        else {
            return
        }
        database.quickButtons.swapAt(firstIndex, secondIndex)
        model.updateQuickButtonStates()
    }

    private func positionPortrait() -> some View {
        Group {
            PositionButtonView(image: "arrow.up.circle") {
                moveLeftRight()
            }
            .disabled(!quickButtonsSettings.twoColumns)
            HStack {
                PositionButtonView(image: "arrow.left.circle") {
                    moveUp()
                }
                PositionButtonView(image: "arrow.down.circle") {
                    moveLeftRight()
                }
                .disabled(!quickButtonsSettings.twoColumns)
                PositionButtonView(image: "arrow.right.circle") {
                    moveDown()
                }
            }
        }
    }

    private func positionLandscape() -> some View {
        Group {
            PositionButtonView(image: "arrow.up.circle") {
                moveUp()
            }
            HStack {
                PositionButtonView(image: "arrow.left.circle") {
                    moveLeftRight()
                }
                .disabled(!quickButtonsSettings.twoColumns)
                PositionButtonView(image: "arrow.down.circle") {
                    moveDown()
                }
                PositionButtonView(image: "arrow.right.circle") {
                    moveLeftRight()
                }
                .disabled(!quickButtonsSettings.twoColumns)
            }
        }
    }

    var body: some View {
        Form {
            Section {
                if #available(iOS 17, *) {
                    Picker(selection: $button.page) {
                        ForEach(1 ... controlBarPages, id: \.self) { page in
                            Text(String(page))
                        }
                    } label: {
                        Text("Page")
                    }
                    .onChange(of: button.page) { _ in
                        model.updateQuickButtonStates()
                    }
                }
                HStack {
                    Text("Position")
                    Spacer()
                    VStack(alignment: .center, spacing: 7) {
                        if orientation.isPortrait {
                            positionPortrait()
                        } else {
                            positionLandscape()
                        }
                    }
                    .font(.title)
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Layout")
            }
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
            switch button.type {
            case .blackScreen:
                QuickButtonStealthModeView(stealthMode: model.stealthMode)
            default:
                EmptyView()
            }
            Section {
                Toggle("Enabled", isOn: $button.enabled)
                    .onChange(of: button.enabled) { _ in
                        model.updateQuickButtonStates()
                    }
                    .disabled(model.getQuickButtonState(type: button.type)?.isOn == true && button.enabled)
            }
            ShortcutSectionView {
                NavigationLink {
                    QuickButtonsSettingsView(model: model)
                } label: {
                    Label("Quick buttons", systemImage: "rectangle.inset.topright.fill")
                }
            }
        }
        .navigationTitle("\(button.name) quick button")
    }
}
