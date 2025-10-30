import MapKit
import SwiftUI

enum NavigationTransportType: CaseIterable {
    case walking
    case cycling
    case automobile
    case transit

    func toSystem() -> MKDirectionsTransportType {
        switch self {
        case .walking:
            return .walking
        case .cycling:
            return .cycling
        case .automobile:
            return .automobile
        case .transit:
            return .transit
        }
    }

    func image() -> String {
        switch self {
        case .walking:
            return "figure.walk"
        case .cycling:
            return "bicycle"
        case .automobile:
            return "car.fill"
        case .transit:
            return "cablecar"
        }
    }
}

@available(iOS 26, *)
class Navigation: ObservableObject {
    static let shared = Navigation()
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var cameraRegion: MKCoordinateRegion?
    @Published var route: MKRoute?
    @Published var isSmall = true
    @Published var destination: MKMapItem?
    @Published var transportType: NavigationTransportType = .walking
    @Published var longPressLocation: MKMapItem?
    @Published var searchText: String = ""
    @Published var searchResults: [MKMapItem] = []
    @Published var followUser: Bool = false
    @Published var followHeading: Bool = false
    let timer = SimpleTimer(queue: .main)
}

extension Model {
    @available(iOS 26, *)
    func navigation() -> Navigation {
        return Navigation.shared
    }

    @available(iOS 26, *)
    func updateNavigationDirections() {
        guard let destination = navigation().destination else {
            return
        }
        navigation().route = nil
        let request = MKDirections.Request()
        request.source = .forCurrentLocation()
        request.destination = destination
        request.transportType = navigation().transportType.toSystem()
        let directions = MKDirections(request: request)
        directions.calculate { response, _ in
            guard let response else {
                return
            }
            self.navigation().route = response.routes.first
        }
    }
}
