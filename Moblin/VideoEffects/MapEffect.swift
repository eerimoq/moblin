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
    private var sceneWidget: SettingsSceneWidget?
    private var location: CLLocation = .init()
    private var size: CGSize = .zero
    private var sceneWidgetMetalPetal: SettingsSceneWidget?
    private var locationMetalPetal: CLLocation = .init()
    private var sizeMetalPetal: CGSize = .zero
    private var newSceneWidget: SettingsSceneWidget?
    private var newLocation: CLLocation = .init()
    private var mapSnapshotter: MKMapSnapshotter?
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

    func setSceneWidget(sceneWidget: SettingsSceneWidget?) {
        mapQueue.sync {
            self.newSceneWidget = sceneWidget
        }
    }

    func updateLocation(location: CLLocation) {
        mapQueue.sync {
            self.newLocation = location
        }
    }

    private func update(size: CGSize) {
        let (newSceneWidget, newLocation) = mapQueue.sync {
            (self.newSceneWidget, self.newLocation)
        }
        guard let newSceneWidget else {
            return
        }
        guard newSceneWidget.extent() != sceneWidget?.extent()
            || size != self.size
            || newLocation.coordinate.latitude != location.coordinate.latitude
            || newLocation.coordinate.longitude != location.coordinate.longitude
        else {
            return
        }
        let options = MKMapSnapshotter.Options()
        let camera = MKMapCamera()
        if !widget.northUp! {
            camera.heading = newLocation.course
        }
        camera.centerCoordinate = newLocation.coordinate
        camera.centerCoordinateDistance = 500
        options.camera = camera
        mapSnapshotter = MKMapSnapshotter(options: options)
        mapSnapshotter?.start(with: DispatchQueue.global(), completionHandler: { snapshot, error in
            guard let snapshot, error == nil, let image = snapshot.image.cgImage, let dot = self.dot else {
                return
            }
            let x = toPixels(newSceneWidget.x, size.width)
            let y = size.height - toPixels(newSceneWidget.y, size.height) - Double(self.widget.height)
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
                .cropped(to: .init(x: 0, y: 0, width: size.width, height: size.height))
            mapQueue.sync {
                self.overlay = overlay
            }
        })
        self.size = size
        sceneWidget = newSceneWidget
        location = newLocation
    }

    private func updateMetalPetal(size: CGSize) {
        let (newSceneWidget, newLocation) = mapQueue.sync {
            (self.newSceneWidget, self.newLocation)
        }
        guard let newSceneWidget else {
            return
        }
        guard newSceneWidget.extent() != sceneWidgetMetalPetal?.extent()
            || size != sizeMetalPetal
            || newLocation.coordinate.latitude != locationMetalPetal.coordinate.latitude
            || newLocation.coordinate.longitude != locationMetalPetal.coordinate.longitude
        else {
            return
        }
        let options = MKMapSnapshotter.Options()
        let camera = MKMapCamera()
        if !widget.northUp! {
            camera.heading = newLocation.course
        }
        camera.centerCoordinate = newLocation.coordinate
        camera.centerCoordinateDistance = 500
        options.camera = camera
        mapSnapshotter = MKMapSnapshotter(options: options)
        mapSnapshotter?.start(with: DispatchQueue.global(), completionHandler: { snapshot, error in
            guard let snapshot, error == nil, let image = snapshot.image.cgImage, let dot = self.dot else {
                return
            }
            let overlay = MTIImage(cgImage: image, isOpaque: false).resized(
                to: .init(width: self.widget.width, height: self.widget.height),
                resizingMode: .aspect
            )
            mapQueue.sync {
                self.overlayMetalPetal = overlay
            }
        })
        sizeMetalPetal = size
        sceneWidgetMetalPetal = newSceneWidget
        locationMetalPetal = newLocation
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        update(size: image.extent.size)
        filter.inputImage = mapQueue.sync { self.overlay }
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        guard let image, let dotImageMetalPetal else {
            return image
        }
        updateMetalPetal(size: image.size)
        let (overlayMetalPetal, sceneWidget) = mapQueue.sync {
            (self.overlayMetalPetal, self.sceneWidgetMetalPetal)
        }
        guard let overlayMetalPetal, let sceneWidget else {
            return image
        }
        let x = toPixels(sceneWidget.x, image.extent.size.width) + overlayMetalPetal.size.width / 2
        let y = toPixels(sceneWidget.y, image.extent.size.height) + overlayMetalPetal.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlayMetalPetal, position: .init(x: x, y: y)),
            .init(content: dotImageMetalPetal, position: .init(x: x, y: y)),
        ]
        return filter.outputImage ?? image
    }
}
