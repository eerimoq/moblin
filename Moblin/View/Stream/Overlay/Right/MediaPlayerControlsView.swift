import SwiftUI

struct StreamOverlayRightMediaPlayerControlsView: View {
    @EnvironmentObject var model: Model

    private func playPauseImage() -> String {
        if model.mediaPlayerPlaying {
            return "pause"
        } else {
            return "play"
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(model.mediaPlayerFileName)
                .foregroundColor(.white)
                .padding([.trailing], 8)
            HStack {
                Text(model.mediaPlayerTime)
                if false {
                    Slider(value: $model.mediaPlayerPosition,
                           in: 0 ... 100,
                           onEditingChanged: { begin in
                               model.mediaPlayerSeeking = begin
                               model.mediaPlayerSetSeeking(on: begin)
                               guard !begin else {
                                   return
                               }
                               model.mediaPlayerSeek(position: Double(model.mediaPlayerPosition))
                           })
                           .frame(width: 250)
                           .accentColor(.white)
                           .onChange(of: model.mediaPlayerPosition) { _ in
                               if model.mediaPlayerSeeking {
                                   model.mediaPlayerSeek(position: Double(model.mediaPlayerPosition))
                               }
                           }
                }
                Button {
                    model.mediaPlayerPrevious()
                } label: {
                    Image(systemName: "arrow.left.to.line.compact")
                        .frame(width: 30)
                        .font(.title)
                }
                Button {
                    model.mediaPlayerTogglePlaying()
                } label: {
                    Image(systemName: playPauseImage())
                        .frame(width: 30)
                        .font(.title)
                }
                Button {
                    model.mediaPlayerNext()
                } label: {
                    Image(systemName: "arrow.right.to.line.compact")
                        .frame(width: 30)
                        .font(.title)
                }
            }
            .padding(8)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}
