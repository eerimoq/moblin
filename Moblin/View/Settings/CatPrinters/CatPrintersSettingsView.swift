import SwiftUI

extension View {
    func integrationImageRow(height: CGFloat? = nil) -> some View {
        frame(maxWidth: 500)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(.white)
            .listRowInsets(EdgeInsets())
            .accessibilityHidden(true)
    }
}

struct IntegrationImageView: View {
    let imageName: String
    var height: CGFloat?

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .integrationImageRow(height: height)
    }
}

private struct CatPrinterSettingsWrapperView: View {
    @ObservedObject var catPrinters: SettingsCatPrinters
    @ObservedObject var device: SettingsCatPrinter
    let status: StatusTopRight

    var body: some View {
        NavigationLink {
            CatPrinterSettingsView(catPrinters: catPrinters, device: device, status: status)
        } label: {
            Text(device.name)
        }
    }
}

struct CatPrintersSettingsView: View {
    let model: Model
    @ObservedObject var catPrinters: SettingsCatPrinters

    var body: some View {
        Form {
            Section {
                IntegrationImageView(imageName: "CatPrinter", height: 180)
            }
            Section {
                Text("A small affordable black and white printer.")
            }
            Section {
                Toggle(isOn: $catPrinters.backgroundPrinting) {
                    Text("Background printing")
                }
            } footer: {
                Text("Print when the app is in background mode.")
            }
            Section {
                List {
                    ForEach(catPrinters.devices) { device in
                        CatPrinterSettingsWrapperView(catPrinters: catPrinters,
                                                      device: device,
                                                      status: model.statusTopRight)
                            .contextMenuDeleteButton {
                                catPrinters.devices.removeAll { $0.id == device.id }
                            }
                    }
                    .onDelete { offsets in
                        catPrinters.devices.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    let device = SettingsCatPrinter()
                    device.name = makeUniqueName(
                        name: SettingsCatPrinter.baseName,
                        existingNames: catPrinters.devices
                    )
                    catPrinters.devices.append(device)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a printer"))
            }
        }
        .navigationTitle("Cat printers")
    }
}
