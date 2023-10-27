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
                    mobs:// deep links can be used to import some settings, often \
                    using QR codes or a browser. See https://github.com/eerimoq/mobs \
                    for details.
                    """)
                }
            }
        }
        .navigationTitle("Import and export settings")
    }
}
