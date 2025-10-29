import MapKit
import SwiftUI

@available(iOS 26, *)
class Navigation: ObservableObject {
    static let shared = Navigation()
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var cameraRegion: MKCoordinateRegion?
    @Published var route: MKRoute?
    @Published var isSmall = true
    @Published var destination: MKMapItem?
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
}
