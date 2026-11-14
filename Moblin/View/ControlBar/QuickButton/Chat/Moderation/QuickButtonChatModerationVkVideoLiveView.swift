import SwiftUI

struct QuickButtonChatModerationVkVideoLiveView: View {
    let model: Model
    @Binding var platform: Platform?

    private func slowModeAction(duration: Int?, onComplete: @escaping (OperationResult) -> Void) {
        model.setVkVideoLiveSlowMode(messageInterval: duration, onComplete: onComplete)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    SlowModeView(durations: [3, 5, 10, 30, 60, 120, 300], action: slowModeAction)
                    EmotesOnlyView(action: model.setVkVideoLiveEmoteOnlyMode)
                } footer: {
                    Text("The VK Video Live API does not support message deletion, bans or timeouts.")
                }
            }
            .navigationTitle("VK Video Live")
            .onAppear {
                platform = .vkVideoLive
            }
        } label: {
            VkVideoLiveLogoAndNameView()
        }
    }
}
