import SwiftUI

struct StreamOverlayRightReplayView: View {
    @EnvironmentObject var model: Model
    @State var position = 20.0

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
                Slider(value: $position,
                       in: 0 ... 30,
                       step: 0.1,
                       onEditingChanged: { _ in
                       })
                       .frame(width: 250)
                       .onChange(of: position) {
                           model.setReplayPosition(offset: $0)
                       }
                Button {
                    model.startReplay(resetImage: false)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 30)
                        .font(.title)
                }
                Button {
                    model.replayPlaying.toggle()
                    if model.replayPlaying {
                        model.replayPlay()
                    } else {
                        model.replayStop()
                    }
                } label: {
                    Image(systemName: playStopImage())
                        .frame(width: 30)
                        .font(.title)
                }
            }
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 7)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(7)
        }
        .padding([.bottom], 4)
    }
}
