import AVFoundation
import MapKit
import MetalPetal
import UIKit
import Vision

private let mapQueue = DispatchQueue(label: "com.eerimoq.widget.map")

final class MapEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var overlay: CIImage?
    private var overlayMetalPetal: MTIImage?
    private let widget: SettingsWidgetMap
    private var x: Double = 0
    private var y: Double = 0
    private var width: Double = 1920
    private var height: Double = 1080
    private var mapSnapshotter: MKMapSnapshotter?
    private var location: CLLocation = .init()
    private let dot: CIImage?
    private let dotImageMetalPetal: MTIImage?

    init(widget: SettingsWidgetMap) {
        self.widget = widget
        if let image = UIImage(named: "MapDot"), let image = image.cgImage {
            dot = CIImage(cgImage: image)
            dotImageMetalPetal = MTIImage(cgImage: image, isOpaque: true)
        } else {
            dot = nil
            dotImageMetalPetal = nil
        }
        super.init()
    }

    override func getName() -> String {
        return "map widget"
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?, size: CGSize?) {
        if let size {
            width = size.width
            height = size.height
        }
        guard let sceneWidget, sceneWidget.x != x || sceneWidget.y != y else {
            return
        }
        x = sceneWidget.x
        y = sceneWidget.y
        update()
    }

    func updateLocation(location: CLLocation) {
        guard location.coordinate.latitude != self.location.coordinate.latitude
            || location.coordinate.longitude != self.location.coordinate.longitude
        else {
            return
        }
        self.location = location
        update()
    }

    private func update() {
        let options = MKMapSnapshotter.Options()
        let camera = MKMapCamera()
        if !widget.northUp! {
            camera.heading = location.course
        }
        camera.centerCoordinate = location.coordinate
        camera.centerCoordinateDistance = 500
        options.camera = camera
        mapSnapshotter = MKMapSnapshotter(options: options)
        mapSnapshotter?.start(with: DispatchQueue.global(), completionHandler: { snapshot, error in
            guard let snapshot, error == nil, let image = snapshot.image.cgImage, let dot = self.dot else {
                return
            }
            let x = (self.width * self.x) / 100
            let y = self.height - (self.height * self.y) / 100 - Double(self.widget.height)
            let overlay = dot
                .transformed(by: CGAffineTransform(
                    translationX: CGFloat(self.widget.width - 30) / 2,
                    y: CGFloat(self.widget.height - 30) / 2
                ))
                .composited(over: CIImage(cgImage: image)
                    .transformed(by: CGAffineTransform(
                        scaleX: CGFloat(self.widget.width) / CGFloat(image.width),
                        y: CGFloat(self.widget.height) / CGFloat(image.width)
                    )))
                .transformed(by: CGAffineTransform(translationX: x, y: y))
                .cropped(to: .init(x: 0, y: 0, width: self.width, height: self.height))
            let metalPetalOverlay = MTIImage(cgImage: image, isOpaque: false).resized(
                to: .init(width: self.widget.width, height: self.widget.height),
                resizingMode: .aspect
            )
            mapQueue.sync {
                self.overlay = overlay
                self.overlayMetalPetal = metalPetalOverlay
            }
        })
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        let overlay = mapQueue.sync {
            self.overlay
        }
        guard let overlay else {
            return image
        }
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        guard let image, let dotImageMetalPetal else {
            return image
        }
        let overlayMetalPetal = mapQueue.sync {
            self.overlayMetalPetal
        }
        guard let overlayMetalPetal else {
            return image
        }
        let x = (image.extent.size.width * self.x) / 100 + overlayMetalPetal.size.width / 2
        let y = (image.extent.size.height * self.y) / 100 + overlayMetalPetal.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlayMetalPetal, position: .init(x: x, y: y)),
            .init(content: dotImageMetalPetal, position: .init(x: x, y: y)),
        ]
        return filter.outputImage ?? image
    }
}
