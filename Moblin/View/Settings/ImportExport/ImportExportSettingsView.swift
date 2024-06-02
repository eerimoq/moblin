import SwiftUI

// private func generateQRCode(from string: String) -> UIImage {
//     let data = string.data(using: String.Encoding.ascii)
//     let filter = CIFilter.qrCodeGenerator()
//     filter.message = data!
//     filter.correctionLevel = "M"
//     let output = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 5, y: 5))
//     let context = CIContext()
//     let cgImage = context.createCGImage(output, from: output.extent)
//     return UIImage(cgImage: cgImage!)
// }

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
                    moblin:// deep links can be used to import some settings, often \
                    using QR codes or a browser. See https://github.com/eerimoq/moblin \
                    for details.
                    """)
                }
            }
            // Section {
            //     HStack {
            //         Spacer()
            //         Button("Export deep link to clipboard") {}
            //         Spacer()
            //     }
            // }
            // Section {
            //     Image(
            //         uiImage: generateQRCode(
            //             from: "moblin:///?Hackigjweoi gjwoeijg  f"
            //         )
            //     )
            //     .resizable()
            //     .interpolation(.none)
            //     .scaledToFit()
            // }
        }
        .navigationTitle("Import and export settings")
        .toolbar {
            SettingsToolbar()
        }
    }
}
