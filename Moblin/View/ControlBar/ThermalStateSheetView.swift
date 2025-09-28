import SwiftUI

private struct CloseToolbar: ToolbarContent {
    @Binding var presenting: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button {
                    presenting = false
                } label: {
                    Text("Close")
                }
            }
        }
    }
}

private struct FlameStateView: View {
    let color: Color
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "flame")
                .padding(4)
                .foregroundColor(color)
                .background(.black)
                .cornerRadius(5)
            Text(text)
        }
    }
}

struct ThermalStateSheetView: View {
    @Binding var presenting: Bool

    var body: some View {
        NavigationStack {
            Form {
                VStack(alignment: .leading) {
                    FlameStateView(color: .white,
                                   text: String(localized: "Your device is cold and should function normally."))
                    FlameStateView(color: .yellow,
                                   text: String(localized: "Your device is warm, but should function normally."))
                    FlameStateView(color: .red,
                                   text: String(localized: "Your device is hot and may overheat."))
                }
            }
            .navigationTitle("Thermal state")
            .toolbar {
                CloseToolbar(presenting: $presenting)
            }
        }
    }
}
