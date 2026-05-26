import Combine
import SwiftUI

private struct StatRow: Identifiable {
    let id: Int
    let icon: String
    let label: String
    let count: Int
    let username: String
}

private class StreamStatisticsState: ObservableObject {
    @Published var rows: [StatRow] = []
    @Published var fontSize: CGFloat = 30
    @Published var foregroundColor: Color = .white
    @Published var backgroundColor: Color = .black.opacity(0.75)
    @Published var width: CGFloat = 0
}

private struct StreamStatisticsView: View {
    @ObservedObject var state: StreamStatisticsState

    var body: some View {
        if !state.rows.isEmpty, state.width > 0 {
            let iconSize = state.fontSize
            let spacing = state.fontSize * 0.3
            VStack(alignment: .leading, spacing: spacing / 2) {
                ForEach(state.rows) { row in
                    HStack(spacing: spacing) {
                        Image(systemName: row.icon)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(state.foregroundColor)
                            .frame(width: iconSize)
                        Text(row.label)
                            .font(.system(size: state.fontSize, weight: .semibold))
                            .foregroundStyle(state.foregroundColor)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if !row.username.isEmpty {
                            Text(row.username)
                                .font(.system(size: state.fontSize * 0.8, weight: .regular))
                                .foregroundStyle(state.foregroundColor.opacity(0.7))
                                .lineLimit(1)
                        }
                        Text("\(row.count)")
                            .font(.system(size: state.fontSize, weight: .bold, design: .monospaced))
                            .foregroundStyle(state.foregroundColor)
                    }
                }
            }
            .padding(.horizontal, state.fontSize * 0.4)
            .padding(.vertical, state.fontSize * 0.3)
            .frame(width: state.width)
            .background(state.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: state.fontSize * 0.4))
        }
    }
}

final class StreamStatisticsEffect: VideoEffect, @unchecked Sendable {
    private let canvasSize: CGSize
    private var settings = SettingsWidgetStreamStatistics()
    private var sceneWidget = SettingsSceneWidget(widgetId: .init())
    private var sceneWidgetPipeline = SettingsSceneWidget(widgetId: .init())
    private var renderer: ImageRenderer<StreamStatisticsView>?
    private var cancellable: AnyCancellable?
    private var overlayImage: CIImage?
    private let state = StreamStatisticsState()
    private var counts: [SettingsWidgetStreamStatisticsItemType: Int] = [:]
    private var latestUsers: [SettingsWidgetStreamStatisticsItemType: String] = [:]

    init(canvasSize: CGSize) {
        self.canvasSize = canvasSize
        super.init()
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidgetPipeline.layout = sceneWidget.layout
        }
        self.sceneWidget.layout = sceneWidget.layout
    }

    @MainActor
    func setSettings(settings: SettingsWidgetStreamStatistics) {
        guard settings !== self.settings else {
            return
        }
        self.settings = settings
        setup()
    }

    @MainActor
    func appendEvent(type: SettingsWidgetStreamStatisticsItemType, delta: Int = 1, username: String = "") {
        counts[type, default: 0] += delta
        if !username.isEmpty {
            latestUsers[type] = username
        }
        updateRows()
    }

    @MainActor
    func resetCounts() {
        counts.removeAll()
        latestUsers.removeAll()
        updateRows()
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        overlayImage?
            .move(sceneWidgetPipeline.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image) ?? image
    }

    @MainActor
    private func setup() {
        cancellable?.cancel()
        state.fontSize = CGFloat(settings.fontSize)
        state.foregroundColor = settings.foregroundColorColor
        state.backgroundColor = settings.backgroundColorColor
        state.width = CGFloat(toPixels(settings.width, canvasSize.minimum()))
        renderer = ImageRenderer(content: StreamStatisticsView(state: state))
        cancellable = renderer?.objectWillChange.sink { [weak self] in
            guard let self else { return }
            setOverlayImage(image: renderer?.ciImage())
        }
        updateRows()
        setOverlayImage(image: renderer?.ciImage())
    }

    @MainActor
    private func updateRows() {
        state.rows = settings.items
            .filter { $0.show }
            .enumerated()
            .map { index, item in
                StatRow(
                    id: index,
                    icon: item.type.systemImage(),
                    label: item.label,
                    count: counts[item.type, default: 0],
                    username: latestUsers[item.type] ?? ""
                )
            }
    }

    private func setOverlayImage(image: CIImage?) {
        processorPipelineQueue.async {
            self.overlayImage = image
        }
    }
}
