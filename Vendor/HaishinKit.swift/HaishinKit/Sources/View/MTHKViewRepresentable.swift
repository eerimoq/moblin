#if os(iOS) || os(tvOS)
import AVFoundation
import SwiftUI

/// A SwiftUI view that displays using a `MTHKView`.
public struct MTHKViewRepresentable: UIViewRepresentable {
    /// A type that presents the captured content.
    public protocol PreviewSource {
        func connect(to view: MTHKView)
    }

    public typealias UIViewType = MTHKView

    /// Specifies the preview source.
    public let previewSource: any PreviewSource
    /// Specifies the videoGravity for MTHKView.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect

    private var view = MTHKView(frame: .zero)

    /// Creates a view representable.
    public init(previewSource: some PreviewSource, videoGravity: AVLayerVideoGravity = .resizeAspect) {
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

    public func makeUIView(context: Context) -> MTHKView {
        previewSource.connect(to: view)
        return view
    }

    public func updateUIView(_ uiView: MTHKView, context: Context) {
        uiView.videoGravity = videoGravity
    }
}

#elseif os(macOS)
import AVFoundation
import SwiftUI

/// A SwiftUI view that displays using a `MTHKView`.
public struct MTHKViewRepresentable: NSViewRepresentable {
    /// A type that presents the captured content.
    public protocol PreviewSource {
        func connect(to view: MTHKView)
    }

    public typealias NSViewType = MTHKView

    /// Specifies the preview source.
    public let previewSource: any PreviewSource
    /// Specifies the videoGravity for MTHKView.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect

    private var view = MTHKView(frame: .zero)

    /// Creates a view representable.
    public init(previewSource: some PreviewSource, videoGravity: AVLayerVideoGravity = .resizeAspect) {
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

    public func makeNSView(context: Context) -> MTHKView {
        previewSource.connect(to: view)
        return view
    }

    public func updateNSView(_ nsView: MTHKView, context: Context) {
        nsView.videoGravity = videoGravity
    }
}

#endif
