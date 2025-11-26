import SwiftUI

struct StreamOverlayRightMediaPlayerControlsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var mediaPlayer: MediaPlayerPlayer

    private func playPauseImage() -> String {
        if mediaPlayer.playing {
            return "pause"
        } else {
            return "play"
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(mediaPlayer.fileName)
                .foregroundStyle(.white)
                .padding([.trailing], 8)
            HStack {
                Text(mediaPlayer.time)
                if false {
                    Slider(value: $mediaPlayer.position,
                           in: 0 ... 100,
                           onEditingChanged: { begin in
                               mediaPlayer.seeking = begin
                               model.mediaPlayerSetSeeking(on: begin)
                               guard !begin else {
                                   return
                               }
                               model.mediaPlayerSeek(position: Double(mediaPlayer.position))
                           })
                           .frame(width: 250)
                           .accentColor(.white)
                           .onChange(of: mediaPlayer.position) { _ in
                               if mediaPlayer.seeking {
                                   model.mediaPlayerSeek(position: Double(model.mediaPlayerPlayer.position))
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
            .foregroundStyle(.white)
            .cornerRadius(8)
        }
    }
}
