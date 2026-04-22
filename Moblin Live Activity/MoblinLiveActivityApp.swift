import SwiftUI
import WidgetKit

private struct MoblinLiveActivityIcon: View {
    var body: some View {
        Image("AppIcon")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

private struct IconAndTextView: View {
    let image: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: image)
                .frame(width: 20)
            Text(text)
        }
        .foregroundColor(.white)
    }
}

private struct MoblinLiveActivityStatusLabel: View {
    let state: LiveActivityAttributes.ContentState

    var body: some View {
        ForEach(state.functions, id: \.image) { function in
            IconAndTextView(image: function.image, text: function.text)
        }
        if state.showEllipsis {
            HStack {
                Image(systemName: "record.circle")
                    .frame(width: 20)
                    .foregroundColor(.clear)
                Text(String("..."))
                    .foregroundColor(.white)
            }
        }
    }
}

@main
struct MoblinLiveActivityApp: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivityAttributes.self) { context in
            VStack(alignment: .leading) {
                HStack {
                    MoblinLiveActivityIcon()
                        .frame(width: 40, height: 40)
                    Text("Moblin is running in background")
                        .lineLimit(1)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Divider()
                MoblinLiveActivityStatusLabel(state: context.state)
                    .padding([.leading], 10)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MoblinLiveActivityIcon()
                        .frame(width: 36, height: 36)
                }
            } compactLeading: {
                MoblinLiveActivityIcon()
            } compactTrailing: {
                EmptyView()
            } minimal: {
                MoblinLiveActivityIcon()
            }
        }
    }
}
