import AVFoundation
import Collections
import MapKit
import MetalPetal
import UIKit
import Vision

private let mapQueue = DispatchQueue(label: "com.eerimoq.widget.map")
var maxMapPitch: Double = 0.0

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
    private var newLocations: Deque<CLLocation> = [.init()]
    private var mapSnapshotter: MKMapSnapshotter?
    private let dot: CIImage?
    private let dotImageMetalPetal: MTIImage?
    private var dotOffsetRatioMetalPetal: Double = 0.0
    private var zoomOutFactor: Int?
    private var isLocationUpdated: Bool = true
    private var pitch: Double = 0.0

    init(widget: SettingsWidgetMap) {
        self.widget = widget.clone()
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

    func zoomOutTemporarily() {
        mapQueue.sync {
            if self.zoomOutFactor == nil {
                self.zoomOutFactor = 2
            }
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?) {
        mapQueue.sync {
            self.newSceneWidget = sceneWidget
        }
    }

    func updateLocation(location: CLLocation) {
        mapQueue.sync {
            self.isLocationUpdated = true
            self.newLocations.append(location)
            if self.newLocations.count > 10 {
                self.newLocations.removeFirst()
            }
        }
    }

    private func nextNewLocation() -> CLLocation {
        let now = Date()
        let delay = widget.delay!
        return newLocations.last(where: { $0.timestamp.advanced(by: delay) <= now }) ?? newLocations.first!
    }

    private func update(size: CGSize) {
        let (newSceneWidget, newLocation, zoomOutFactor, isLocationUpdated) = mapQueue.sync {
            defer {
                self.isLocationUpdated = false
            }
            return (self.newSceneWidget, self.nextNewLocation(), self.zoomOutFactor, self.isLocationUpdated)
        }
        guard let newSceneWidget else {
            return
        }
        guard newSceneWidget.extent() != sceneWidget?.extent()
            || size != self.size
            || newLocation.coordinate.latitude != location.coordinate.latitude
            || newLocation.coordinate.longitude != location.coordinate.longitude
            || newLocation.speed != location.speed
            || (zoomOutFactor != nil && isLocationUpdated)
        else {
            return
        }
        let (mapSnapshotter, dotOffsetRatio, forceUpdate) = createSnapshotter(
            newLocation: newLocation,
            zoomOutFactor: zoomOutFactor
        )
        self.mapSnapshotter = mapSnapshotter
        self.mapSnapshotter?.start(with: DispatchQueue.global(), completionHandler: { snapshot, error in
            guard let snapshot, error == nil, let image = snapshot.image.cgImage, let dot = self.dot else {
                return
            }
            let height = toPixels(newSceneWidget.height, size.height)
            let width = toPixels(newSceneWidget.width, size.width)
            let side = max(40, min(height, width))
            let x = toPixels(newSceneWidget.x, size.width)
            let y = size.height - toPixels(newSceneWidget.y, size.height) - side
            let overlay = dot
                .transformed(by: CGAffineTransform(
                    translationX: CGFloat(side - 30) / 2,
                    y: CGFloat(side - 30) / 2 -
                        CGFloat(dotOffsetRatio * CGFloat(side) / 2)
                ))
                .composited(over: CIImage(cgImage: image)
                    .transformed(by: CGAffineTransform(
                        scaleX: CGFloat(side) / CGFloat(image.width),
                        y: CGFloat(side) / CGFloat(image.width)
                    )))
                .transformed(by: CGAffineTransform(translationX: x, y: y))
                .cropped(to: .init(x: 0, y: 0, width: size.width, height: size.height))
            mapQueue.sync {
                self.overlay = overlay
            }
        })
        if forceUpdate {
            sceneWidget = nil
        } else {
            sceneWidget = newSceneWidget
        }
        self.size = size
        location = newLocation
    }

    private func updateMetalPetal(size: CGSize) {
        let (newSceneWidget, newLocation, zoomOutStep, isLocationUpdated) = mapQueue.sync {
            defer {
                self.isLocationUpdated = false
            }
            return (self.newSceneWidget, self.nextNewLocation(), self.zoomOutFactor, self.isLocationUpdated)
        }
        guard let newSceneWidget else {
            return
        }
        guard newSceneWidget.extent() != sceneWidgetMetalPetal?.extent()
            || size != sizeMetalPetal
            || newLocation.coordinate.latitude != locationMetalPetal.coordinate.latitude
            || newLocation.coordinate.longitude != locationMetalPetal.coordinate.longitude
            || newLocation.speed != locationMetalPetal.speed
            || (zoomOutStep != nil && isLocationUpdated)
        else {
            return
        }
        let (mapSnapshotter, dotOffsetRatio, forceUpdate) = createSnapshotter(
            newLocation: newLocation,
            zoomOutFactor: zoomOutFactor
        )
        self.mapSnapshotter = mapSnapshotter
        self.mapSnapshotter?.start(with: DispatchQueue.global(), completionHandler: { snapshot, error in
            guard let snapshot, error == nil, let image = snapshot.image.cgImage else {
                return
            }
            let height = toPixels(newSceneWidget.height, size.height)
            let width = toPixels(newSceneWidget.width, size.width)
            let side = max(40, min(height, width))
            let overlay = MTIImage(cgImage: image, isOpaque: false).resized(
                to: .init(width: side, height: side),
                resizingMode: .aspect
            )
            mapQueue.sync {
                self.overlayMetalPetal = overlay
                self.dotOffsetRatioMetalPetal = dotOffsetRatio
            }
        })
        if forceUpdate {
            sceneWidgetMetalPetal = nil
        } else {
            sceneWidgetMetalPetal = newSceneWidget
        }
        sizeMetalPetal = size
        locationMetalPetal = newLocation
    }

    private func createSnapshotter(newLocation: CLLocation,
                                   zoomOutFactor: Int?) -> (MKMapSnapshotter, Double, Bool)
    {
        let camera = MKMapCamera()
        if !widget.northUp! {
            camera.heading = newLocation.course
        }
        camera.centerCoordinate = newLocation.coordinate
        camera.centerCoordinateDistance = 1000
        var dotOffsetRatio = 0.0
        if newLocation.speed > 4, zoomOutFactor == nil {
            camera.centerCoordinateDistance += 150 * (newLocation.speed - 4)
            if !widget.northUp! {
                let halfMapSideLength = tan(.pi / 12) * camera.centerCoordinateDistance
                let maxDotOffsetFromCenter = halfMapSideLength / 2
                let maxDotSpeed = 20.0
                let k = maxDotOffsetFromCenter / (maxDotSpeed - 4)
                var dotOffsetInMeters = k * (newLocation.speed - 4)
                if dotOffsetInMeters > maxDotOffsetFromCenter {
                    dotOffsetInMeters = maxDotOffsetFromCenter
                }
                let course = toRadians(degrees: max(newLocation.course, 0))
                let latitudeOffsetInMeters = cos(course) * dotOffsetInMeters
                let longitudeOffsetInMeters = sin(course) * dotOffsetInMeters
                camera.centerCoordinate = newLocation.coordinate.translateMeters(
                    x: longitudeOffsetInMeters,
                    y: latitudeOffsetInMeters
                )
                dotOffsetRatio = dotOffsetInMeters / halfMapSideLength
            }
        }
        if newLocation.speed > 4 {
            pitch = -maxMapPitch
        } else if newLocation.speed < 1 {
            pitch = 0
        }
        camera.pitch = pitch
        var forceUpdate = false
        if let zoomOutFactor {
            camera.centerCoordinateDistance *= pow(5, Double(zoomOutFactor))
            if zoomOutFactor > 9 {
                mapQueue.sync {
                    self.zoomOutFactor = nil
                }
                forceUpdate = true
            } else {
                mapQueue.sync {
                    self.zoomOutFactor = zoomOutFactor + 1
                }
            }
        }
        let options = MKMapSnapshotter.Options()
        options.camera = camera
        return (MKMapSnapshotter(options: options), dotOffsetRatio, forceUpdate)
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
        let (overlayMetalPetal, sceneWidget, dotOffsetRatioMetalPetal) = mapQueue.sync {
            (self.overlayMetalPetal, self.sceneWidgetMetalPetal, self.dotOffsetRatioMetalPetal)
        }
        guard let overlayMetalPetal, let sceneWidget else {
            return image
        }
        let x = toPixels(sceneWidget.x, image.extent.size.width) + overlayMetalPetal.size.width / 2
        let y = toPixels(sceneWidget.y, image.extent.size.height) + overlayMetalPetal.size.height / 2
        let yDot = toPixels(sceneWidget.y, image.extent.size.height) + overlayMetalPetal.size
            .height / 2 + dotOffsetRatioMetalPetal * overlayMetalPetal.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlayMetalPetal, position: .init(x: x, y: y)),
            .init(content: dotImageMetalPetal, position: .init(x: x, y: yDot)),
        ]
        return filter.outputImage ?? image
    }
}
