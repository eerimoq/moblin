import SwiftUI

private struct CatPrinterSettingsWrapperView: View {
    var device: SettingsCatPrinter
    @State var name: String

    var body: some View {
        NavigationLink {
            CatPrinterSettingsView(device: device, name: $name)
        } label: {
            Text(name)
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
                    Image("CatPrinter")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 130)
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
                        CatPrinterSettingsWrapperView(device: device, name: device.name)
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
