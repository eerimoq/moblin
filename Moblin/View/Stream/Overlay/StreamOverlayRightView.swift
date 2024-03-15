import SwiftUI

private let segmentHeight = 40.0
private let zoomSegmentWidth = 50.0
private let sceneSegmentWidth = 70.0
private let pickerBorderColor = Color.gray
private var pickerBackgroundColor = Color.black.opacity(0.6)

private struct SegmentedPicker<T: Equatable, Content: View>: View {
    @Namespace private var selectionAnimation
    @Binding var selectedItem: T?
    private let items: [T]
    private let content: (T) -> Content

    init(_ items: [T],
         selectedItem: Binding<T?>,
         @ViewBuilder content: @escaping (T) -> Content)
    {
        _selectedItem = selectedItem
        self.items = items
        self.content = content
    }

    @ViewBuilder func overlay(for item: T) -> some View {
        if item == selectedItem {
            RoundedRectangle(cornerRadius: 6)
                .fill(.gray.opacity(0.6))
                .padding(2)
                .matchedGeometryEffect(id: "selectedSegmentHighlight", in: selectionAnimation)
        }
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(self.items.indices, id: \.self) { index in
                ZStack {
                    Rectangle()
                        .overlay(self.overlay(for: self.items[index]))
                        .foregroundColor(.black.opacity(0.1))
                    Button(action: {
                        withAnimation(.linear.speed(1.5)) {
                            self.selectedItem = self.items[index]
                        }
                    }, label: {
                        self.content(self.items[index])
                    })
                }
                Divider()
                    .background(pickerBorderColor)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct RightOverlayView: View {
    @EnvironmentObject var model: Model

    private var database: Database {
        model.settings.database
    }

    private func netStreamColor() -> Color {
        if model.isStreaming() {
            switch model.streamState {
            case .connecting:
                return .white
            case .connected:
                return .white
            case .disconnected:
                return .red
            }
        } else {
            return .white
        }
    }

    private func remoteControlColor() -> Color {
        if model.isRemoteControlStreamerConfigured() && !model.isRemoteControlStreamerConnected() {
            return .red
        } else if model.isRemoteControlAssistantConfigured() && !model.isRemoteControlAssistantConnected() {
            return .red
        }
        return .white
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if model.isShowingStatusAudioLevel() {
                AudioLevelView(
                    showBar: database.show.audioBar,
                    level: model.audioLevel,
                    channels: model.numberOfAudioChannels
                )
            }
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusRtmpServer(),
                icon: "server.rack",
                text: model.rtmpSpeedAndTotal,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusRemoteControl(),
                icon: "appletvremote.gen1",
                text: model.remoteControlStatus,
                textFirst: true,
                color: remoteControlColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusGameController(),
                icon: "gamecontroller",
                text: model.gameControllersTotal,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusBitrate(),
                icon: "speedometer",
                text: model.speedAndTotal,
                textFirst: true,
                color: netStreamColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusUptime(),
                icon: "deskclock",
                text: model.uptime,
                textFirst: true,
                color: netStreamColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusLocation(),
                icon: "location",
                text: model.location,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusSrtla(),
                icon: "phone.connection",
                text: model.srtlaConnectionStatistics,
                textFirst: true,
                color: netStreamColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusRecording(),
                icon: "record.circle",
                text: model.recordingLength,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusBrowserWidgets(),
                icon: "globe",
                text: model.browserWidgetsStatus,
                textFirst: true,
                color: .white
            )
            Spacer()
            if !model.showDrawOnStream {
                if database.show.zoomPresets && model.hasZoom {
                    if model.cameraPosition == .front {
                        SegmentedPicker(database.zoom.front, selectedItem: Binding(get: {
                            database.zoom.front.first { $0.id == model.frontZoomPresetId }
                        }, set: { value in
                            if let value {
                                model.frontZoomPresetId = value.id
                            }
                        })) {
                            Text($0.name)
                                .font(.subheadline)
                                .frame(width: zoomSegmentWidth, height: segmentHeight)
                        }
                        .onChange(of: model.frontZoomPresetId) { id in
                            model.setCameraZoomPreset(id: id)
                        }
                        .background(pickerBackgroundColor)
                        .foregroundColor(.white)
                        .frame(width: zoomSegmentWidth * Double(database.zoom.front.count))
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(pickerBorderColor)
                        )
                        .padding([.bottom], 5)
                    } else {
                        SegmentedPicker(model.backZoomPresets(), selectedItem: Binding(get: {
                            model.backZoomPresets().first { $0.id == model.backZoomPresetId }
                        }, set: { value in
                            if let value {
                                model.backZoomPresetId = value.id
                            }
                        })) {
                            Text($0.name)
                                .font(.subheadline)
                                .frame(width: zoomSegmentWidth, height: segmentHeight)
                        }
                        .onChange(of: model.backZoomPresetId) { id in
                            model.setCameraZoomPreset(id: id)
                        }
                        .background(pickerBackgroundColor)
                        .foregroundColor(.white)
                        .frame(width: zoomSegmentWidth * Double(model.backZoomPresets().count))
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(pickerBorderColor)
                        )
                        .padding([.bottom], 5)
                    }
                }
                SegmentedPicker(model.enabledScenes, selectedItem: Binding(get: {
                    if model.sceneIndex < model.enabledScenes.count {
                        model.enabledScenes[model.sceneIndex]
                    } else {
                        nil
                    }
                }, set: { value in
                    if let value, let index = model.enabledScenes.firstIndex(of: value) {
                        model.sceneIndex = index
                    } else {
                        model.sceneIndex = 0
                    }
                })) {
                    Text($0.name)
                        .font(.subheadline)
                        .frame(width: sceneSegmentWidth, height: segmentHeight)
                }
                .onChange(of: model.sceneIndex) { tag in
                    model.setSceneId(id: model.enabledScenes[tag].id)
                    model.sceneUpdated(store: false, scrollQuickButtons: true)
                }
                .background(pickerBackgroundColor)
                .foregroundColor(.white)
                .frame(width: sceneSegmentWidth * Double(model.enabledScenes.count))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(pickerBorderColor)
                )
            }
        }
    }
}
