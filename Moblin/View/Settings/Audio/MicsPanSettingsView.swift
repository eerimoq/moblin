import SwiftUI

func formatPan(_ pan: Float) -> String {
    let percent = Int((abs(pan) * 100).rounded())
    if percent == 0 {
        return String(localized: "Center")
    } else if pan < 0 {
        return String(localized: "L \(percent)")
    } else {
        return String(localized: "R \(percent)")
    }
}

private struct MicPanView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic

    var body: some View {
        VStack(alignment: .leading) {
            Text(mic.name)
                .lineLimit(1)
            HStack {
                Slider(value: $mic.pan, in: -1.0 ... 1.0, step: 0.05)
                    .onChange(of: mic.pan) { _ in
                        model.updateMixedMics()
                    }
                Text(formatPan(mic.pan))
                    .frame(width: 65)
            }
        }
    }
}

struct MicsPanSettingsView: View {
    let model: Model
    @ObservedObject var mic: Mic

    var body: some View {
        Form {
            Section {
                ForEach([model.getMicById(id: mic.current.id) ?? mic.current] + mic.mixed) { mic in
                    MicPanView(model: model, mic: mic)
                }
            } footer: {
                Text("Places the selected mic and each mic mixed into it between left and right.")
            }
        }
        .navigationTitle("Pans")
    }
}
