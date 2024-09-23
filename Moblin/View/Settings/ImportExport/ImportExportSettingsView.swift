import SwiftUI

struct ImportExportSettingsView: View {
    var body: some View {
        Form {
            Section {
                ImportSettingsView()
            }
            Section {
                ExportSettingsView()
            } footer: {
                VStack(alignment: .leading) {
                    Text("")
                    Text("""
                    Do not share your settings with anyone as they may contain \
                    sensitive data (stream keys, etc.)!
                    """).bold()
                    Text("")
                    Text("""
                    It is not recommended to export settings from one device and import them \
                    in another. Some settings will not work on other devices. Deep links, on \
                    the other hand, can be imported on any device.
                    """)
                    Text("")
                    Text("""
                    moblin:// deep links can be used to import some settings, often \
                    using QR codes or a browser. See https://github.com/eerimoq/moblin \
                    for details.
                    """)
                }
            }
        }
        .navigationTitle("Import and export settings")
    }
}
