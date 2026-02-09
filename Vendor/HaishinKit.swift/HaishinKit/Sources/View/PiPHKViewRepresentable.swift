#if os(iOS) || os(tvOS) || os(visionOS)
import AVFoundation
import SwiftUI

/// A SwiftUI view that displays using a `PiPHKView`.
public struct PiPHKViewRepresentable: UIViewRepresentable {
    /// A type that presents the captured content.
    public protocol PreviewSource {
        func connect(to view: PiPHKView)
    }

    public typealias UIViewType = PiPHKView

    /// Specifies the preview source.
    public let previewSource: any PreviewSource
    /// Specifies the videoGravity for PiPHKView.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect

    private var view = PiPHKView(frame: .zero)

    /// Creates a view representable.
    public init(previewSource: any PreviewSource, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        self.previewSource = previewSource
        self.videoGravity = videoGravity
    }

    /// Selects track id for streaming.
    public func track(_ id: UInt8?) -> Self {
        Task { @MainActor in
            await view.selectTrack(id, mediaType: .video)
        }
        return self
    }

    public func makeUIView(context: Context) -> PiPHKView {
        previewSource.connect(to: view)
        return view
    }

    public func updateUIView(_ uiView: PiPHKView, context: Context) {
        uiView.videoGravity = videoGravity
    }
}

#else
import AVFoundation
import SwiftUI

/// A SwiftUI view that displays using a `PiPHKView`.
public struct PiPHKViewRepresentable: NSViewRepresentable {
    /// A type that presents the captured content.
    public protocol PreviewSource {
        func connect(to view: PiPHKView)
    }

    public typealias NSViewType = PiPHKView

    /// Specifies the preview source.
    public let previewSource: any PreviewSource
    /// Specifies the videoGravity for PiPHKView.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect

    private var view = PiPHKView(frame: .zero)

    /// Creates a view representable.
    public init(previewSource: any PreviewSource, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        self.previewSource = previewSource
        self.videoGravity = videoGravity
    }

    /// Selects track id for streaming.
    public func track(_ id: UInt8?) -> Self {
        Task { @MainActor in
            await view.selectTrack(id, mediaType: .video)
        }
        return self
    }

    public func makeNSView(context: Context) -> PiPHKView {
        previewSource.connect(to: view)
        return view
    }

    public func updateNSView(_ nsView: PiPHKView, context: Context) {
        nsView.videoGravity = videoGravity
    }
}

#endif
