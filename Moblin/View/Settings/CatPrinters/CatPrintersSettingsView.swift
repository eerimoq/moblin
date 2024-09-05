import SwiftUI

struct CatPrintersSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.catPrinters!.devices) { device in
                        NavigationLink(destination: CatPrinterSettingsView(device: device)) {
                            Text(device.name)
                        }
                    }
                    .onDelete(perform: { offsets in
                        model.database.catPrinters!.devices.remove(atOffsets: offsets)
                        model.store()
                    })
                }
                CreateButtonView(action: {
                    let device = SettingsCatPrinter()
                    device.name = "My printer"
                    model.database.catPrinters!.devices.append(device)
                    model.objectWillChange.send()
                })
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a printer"))
            }
        }
        .navigationTitle("Cat printers")
        .toolbar {
            SettingsToolbar()
        }
    }
}
