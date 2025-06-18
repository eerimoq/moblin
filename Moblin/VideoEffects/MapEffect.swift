import AVFoundation
import Collections
import MapKit
import UIKit
import Vision

final class MapEffect: VideoEffect {
    private var mapSnapshot: CIImage?
    private let widget: SettingsWidgetMap
    private var sceneWidget: SettingsSceneWidget?
    private var location: CLLocation = .init()
    private var size: CGSize = .zero
    private var newLocations: Deque<CLLocation> = [.init()]
    private var mapSnapshotter: MKMapSnapshotter?
    private let dot: CIImage?
    private var dotOffsetRatio = 0.0
    private var zoomOutFactor: Int?
    private var isLocationUpdated: Bool = true

    init(widget: SettingsWidgetMap) {
        self.widget = widget.clone()
        if let image = UIImage(named: "MapDot"), let image = image.cgImage {
            dot = CIImage(cgImage: image)
        } else {
            dot = nil
        }
        super.init()
    }

    override func getName() -> String {
        return "map widget"
    }

    func zoomOutTemporarily() {
        mixerLockQueue.async {
            if self.zoomOutFactor == nil {
                self.zoomOutFactor = 2
            }
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?) {
        mixerLockQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    func updateLocation(location: CLLocation) {
        mixerLockQueue.async {
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
        let (newLocation, zoomOutFactor, isLocationUpdated) = {
            defer {
                self.isLocationUpdated = false
            }
            return (self.nextNewLocation(), self.zoomOutFactor, self.isLocationUpdated)
        }()
        guard size != self.size
            || newLocation.coordinate.latitude != location.coordinate.latitude
            || newLocation.coordinate.longitude != location.coordinate.longitude
            || newLocation.speed != location.speed
            || (zoomOutFactor != nil && isLocationUpdated)
        else {
            return
        }
        let (mapSnapshotter, dotOffsetRatio) = createSnapshotter(
            newLocation: newLocation,
            zoomOutFactor: zoomOutFactor
        )
        self.mapSnapshotter = mapSnapshotter
        self.mapSnapshotter?.start(with: DispatchQueue.global(), completionHandler: { snapshot, error in
            guard let snapshot, error == nil, let image = snapshot.image.cgImage else {
                return
            }
            mixerLockQueue.async {
                self.mapSnapshot = CIImage(cgImage: image)
                self.dotOffsetRatio = dotOffsetRatio
            }
        })
        self.size = size
        location = newLocation
    }

    private func createSnapshotter(newLocation: CLLocation, zoomOutFactor: Int?) -> (MKMapSnapshotter, Double) {
        var zoomOutFactor = zoomOutFactor
        if zoomOutFactor == 10 {
            zoomOutFactor = nil
            self.zoomOutFactor = nil
        }
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
        camera.pitch = 0
        if let zoomOutFactor {
            camera.centerCoordinateDistance *= pow(5, Double(zoomOutFactor))
            if zoomOutFactor <= 9 {
                self.zoomOutFactor = zoomOutFactor + 1
            }
        }
        let options = MKMapSnapshotter.Options()
        options.camera = camera
        return (MKMapSnapshotter(options: options), dotOffsetRatio)
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let size = image.extent.size
        update(size: size)
        guard let sceneWidget, let dot, let mapSnapshot else {
            return image
        }
        let height = toPixels(sceneWidget.height, size.height)
        let width = toPixels(sceneWidget.width, size.width)
        let side = max(40, min(height, width))
        let x = toPixels(sceneWidget.x, size.width)
        let y = size.height - toPixels(sceneWidget.y, size.height) - side
        return dot
            .transformed(by: CGAffineTransform(
                translationX: CGFloat(side - 30) / 2,
                y: CGFloat(side - 30) / 2 - CGFloat(dotOffsetRatio * CGFloat(side) / 2)
            ))
            .composited(over: applyEffects(mapSnapshot, info)
                .transformed(by: CGAffineTransform(
                    scaleX: CGFloat(side) / CGFloat(mapSnapshot.extent.width),
                    y: CGFloat(side) / CGFloat(mapSnapshot.extent.width)
                )))
            .transformed(by: CGAffineTransform(translationX: x, y: y))
            .cropped(to: image.extent)
            .composited(over: image)
    }
}
