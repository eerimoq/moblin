import SwiftUI

struct IntegrationImageView: View {
    let imageName: String

    var body: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 130.0)
    }
}

private struct CatPrinterSettingsWrapperView: View {
    @ObservedObject var device: SettingsCatPrinter

    var body: some View {
        NavigationLink {
            CatPrinterSettingsView(device: device)
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
                Toggle(isOn: $catPrinters.backgroundPrinting) {
                    Text("Background printing")
                }
            } footer: {
                Text("Print when the app is in background mode.")
            }
            Section {
                List {
                    ForEach(catPrinters.devices) { device in
                        CatPrinterSettingsWrapperView(device: device)
                    }
                    .onDelete(perform: { offsets in
                        catPrinters.devices.remove(atOffsets: offsets)
                    })
                }
                CreateButtonView {
                    let device = SettingsCatPrinter()
                    device.name = "My printer"
                    catPrinters.devices.append(device)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a printer"))
            }
        }
        .navigationTitle("Cat printers")
    }
}
