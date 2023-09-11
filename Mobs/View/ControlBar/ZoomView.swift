import SwiftUI

struct ZoomView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        Slider(value: $model.zoomLevel, in: 1...5, step: 0.1)
            .onChange(of: model.zoomLevel) { level in
                model.setCameraZoomLevel(level: level)
            }
    }
}
