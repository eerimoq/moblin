import SwiftUI

struct CatPrintersSettingsView: View {
    @EnvironmentObject var model: Model

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
                Toggle(isOn: Binding(get: {
                    model.database.catPrinters!.backgroundPrinting!
                }, set: { value in
                    model.database.catPrinters!.backgroundPrinting = value
                }), label: {
                    Text("Background printing")
                })
            } footer: {
                Text("Print when the app is in background mode.")
            }
            Section {
                List {
                    ForEach(model.database.catPrinters!.devices) { device in
                        NavigationLink {
                            CatPrinterSettingsView(device: device)
                        } label: {
                            Text(device.name)
                        }
                    }
                    .onDelete(perform: { offsets in
                        model.database.catPrinters!.devices.remove(atOffsets: offsets)
                    })
                }
                CreateButtonView {
                    let device = SettingsCatPrinter()
                    device.name = "My printer"
                    model.database.catPrinters!.devices.append(device)
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a printer"))
            }
        }
        .navigationTitle("Cat printers")
    }
}
