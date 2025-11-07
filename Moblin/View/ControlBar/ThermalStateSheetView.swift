import SwiftUI

private struct CloseToolbar: ToolbarContent {
    @Binding var presenting: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                presenting = false
            } label: {
                Image(systemName: "xmark")
            }
        }
    }
}

private struct FlameStateView: View {
    let color: Color
    let text: LocalizedStringKey

    var body: some View {
        HStack {
            Image(systemName: "flame")
                .padding(4)
                .foregroundStyle(color)
                .background(.black)
                .cornerRadius(5)
            Text(text)
        }
    }
}

private struct BulletView: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 0) {
            Text(String("• "))
            Text(text)
        }
    }
}

struct ThermalStateSheetView: View {
    @Binding var presenting: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        FlameStateView(color: .white, text: "Your device is cold and should function normally.")
                        FlameStateView(color: .yellow, text: "Your device is warm, but should function normally.")
                        FlameStateView(color: .red, text: "Your device is hot and may overheat.")
                    }
                }
                Section {
                    VStack(alignment: .leading) {
                        BulletView(text: "Use single lens or low energy cameras")
                        BulletView(text: "Lower FPS")
                        BulletView(text: "Lower resolution")
                        BulletView(text: "Lower bitrate")
                        BulletView(text: "No widgets, LUTs or other image effects")
                        BulletView(text: "No direct sunlight")
                        BulletView(text: "More air flow")
                        BulletView(text: "Keep the battery fully charged")
                        BulletView(text: "No wireless charging or fast charging")
                        BulletView(text: "Use a phone cooler")
                        BulletView(text: "Turn off cellular")
                        BulletView(text: "Turn off busy chats")
                        BulletView(text: "And a lot more...")
                    }
                } header: {
                    Text("Mitigating overheating")
                }
            }
            .navigationTitle("Thermal state")
            .toolbar {
                CloseToolbar(presenting: $presenting)
            }
        }
    }
}
