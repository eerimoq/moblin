import MapKit
import SwiftUI

enum NavigationTransportType: CaseIterable {
    case walking
    case cycling
    case automobile

    func toSystem() -> MKDirectionsTransportType {
        switch self {
        case .walking:
            .walking
        case .cycling:
            .cycling
        case .automobile:
            .automobile
        }
    }

    func image() -> String {
        switch self {
        case .walking:
            "figure.walk"
        case .cycling:
            "bicycle"
        case .automobile:
            "car.fill"
        }
    }
}

@available(iOS 26, *)
class Navigation: ObservableObject {
    static let shared = Navigation()
    @Published var cameraPosition: MapCameraPosition = .automatic
    var cameraRegion: MKCoordinateRegion?
    @Published var route: MKRoute?
    @Published var isSmall = true
    @Published var destination: MKMapItem?
    @Published var transportType: NavigationTransportType = .walking
    @Published var longPressLocation: MKMapItem?
    @Published var searchText: String = ""
    @Published var searchResults: [MKMapItem] = []
    let timer = SimpleTimer(queue: .main)

    func updateCameraPosition(settings: SettingsNavigation, region: MKCoordinateRegion? = nil) {
        guard let region = region ?? cameraRegion else {
            return
        }
        if settings.followUser {
            cameraPosition = .userLocation(followsHeading: settings.followHeading, fallback: .region(region))
        } else {
            cameraPosition = .region(region)
        }
    }

    func updateDirections() {
        guard let destination else {
            return
        }
        route = nil
        let request = MKDirections.Request()
        request.source = .forCurrentLocation()
        request.destination = destination
        request.transportType = transportType.toSystem()
        let directions = MKDirections(request: request)
        directions.calculate { response, _ in
            guard let response else {
                return
            }
            self.route = response.routes.first
        }
    }
}

extension Model {
    @available(iOS 26, *)
    func navigation() -> Navigation {
        Navigation.shared
    }
}
