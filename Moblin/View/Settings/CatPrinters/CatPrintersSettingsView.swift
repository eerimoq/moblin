import SwiftUI

struct IntegrationImageView: View {
    let imageName: String
    var height: Double?

    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .background(.white)
            .frame(height: height ?? 130.0)
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
    @EnvironmentObject var model: Model
    @ObservedObject var catPrinters: SettingsCatPrinters

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "CatPrinter")
                }
                Text("A small affordable black and white printer.")
            }
            Section {
                List {
                    ForEach(catPrinters.devices) { device in
                        CatPrinterSettingsWrapperView(catPrinters: catPrinters,
                                                      device: device,
                                                      status: model.statusTopRight)
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
