import SwiftUI

struct StreamOverlayRightReplayView: View {
    @EnvironmentObject var model: Model

    private func playStopImage() -> String {
        if model.replayPlaying {
            return "stop"
        } else {
            return "play"
        }
    }

    var body: some View {
        VStack(alignment: .trailing) {
            if let image = model.replayImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 300)
                    .cornerRadius(7)
            }
            HStack {
                Slider(value: $model.replayPosition,
                       in: 0 ... 30,
                       step: 0.1,
                       onEditingChanged: { _ in
                       })
                       .frame(width: 250)
                       .onChange(of: model.replayPosition) {
                           model.setReplayPosition(offset: 30 - $0)
                       }
                       .rotationEffect(.degrees(180))
                Text("\(Int(model.replayPosition))s")
                    .frame(width: 30)
                    .font(.body)
                SegmentedPicker(SettingsReplaySpeed.allCases, selectedItem: $model.replaySpeed) {
                    Text($0.rawValue)
                        .font(.subheadline)
                        .frame(width: 30, height: 35)
                }
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(pickerBorderColor)
                )
                .frame(width: 90)
                .onChange(of: model.replaySpeed) { _ in
                    model.replaySpeedChanged()
                }
                Button {
                    model.startReplay(resetImage: false)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 30)
                }
                Button {
                    model.replayPlaying.toggle()
                    if model.replayPlaying {
                        if !model.replayPlay() {
                            model.replayPlaying = false
                        }
                    } else {
                        model.replayCancel()
                    }
                } label: {
                    Image(systemName: playStopImage())
                        .frame(width: 30)
                }
            }
            .font(.title)
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 7)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(7)
        }
        .padding([.bottom], 4)
    }
}
