import GeoToolbox
import MapKit
import SwiftUI

private let smallMapSide = 200.0
private let maximumBigMapSide = 600.0

private struct ImageLocationView: View {
    let slash: Bool

    var body: some View {
        Image(systemName: slash ? "location.slash" : "location")
            .offset(CGSize(width: -8, height: 0))
    }
}

private struct ImageConeView: View {
    let slash: Bool

    var body: some View {
        ZStack {
            Image(systemName: "cone")
                .scaleEffect(0.9)
                .rotationEffect(.degrees(180))
            if slash {
                Image(systemName: "line.diagonal")
                    .rotationEffect(.degrees(90))
            }
        }
        .offset(CGSize(width: 8, height: 0))
    }
}

@available(iOS 26, *)
private struct ControlSearchView: View {
    @ObservedObject var navigation: Navigation

    private func search(text: String) {
        guard let cameraRegion = navigation.cameraRegion, !text.isEmpty else {
            return
        }
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = text
        searchRequest.region = cameraRegion
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, _ in
            guard let response else {
                return
            }
            navigation.searchResults = response.mapItems
        }
    }

    var body: some View {
        if !navigation.isSmall {
            TextField("What are you looking for?", text: $navigation.searchText)
                .frame(maxWidth: 300, maxHeight: 20)
                .padding(12)
                .glassEffect()
                .onSubmit {
                    search(text: navigation.searchText)
                }
                .onChange(of: navigation.searchText) { _ in
                    if navigation.searchText.isEmpty {
                        navigation.searchResults.removeAll()
                    }
                }
            Picker("", selection: $navigation.transportType) {
                ForEach(NavigationTransportType.allCases, id: \.self) { transportType in
                    Image(systemName: transportType.image())
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(.primary)
            .frame(width: 35, height: 12)
            .padding()
            .glassEffect()
            .onChange(of: navigation.transportType) { _ in
                navigation.updateDirections()
            }
        }
    }
}

@available(iOS 26, *)
private struct ControlsView: View {
    @ObservedObject var navigationSettings: SettingsNavigation
    @ObservedObject var navigation: Navigation
    let metrics: GeometryProxy

    private func minMaxButtonIcon() -> String {
        if navigation.isSmall {
            return "arrow.up.left.and.arrow.down.right"
        } else {
            return "arrow.down.right.and.arrow.up.left"
        }
    }

    private func shouldStackVertically() -> Bool {
        return metrics.size.width < maximumBigMapSide
    }

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if shouldStackVertically() {
                    ControlSearchView(navigation: navigation)
                        .padding([.trailing], 10)
                }
            }
            HStack {
                Spacer()
                if !shouldStackVertically() {
                    ControlSearchView(navigation: navigation)
                }
                Button {
                    if navigationSettings.followUser, navigationSettings.followHeading {
                        navigationSettings.followUser = false
                        navigationSettings.followHeading = false
                    } else if !navigationSettings.followUser, !navigationSettings.followHeading {
                        navigationSettings.followUser = true
                    } else if navigationSettings.followUser, !navigationSettings.followHeading {
                        navigationSettings.followHeading = true
                    }
                } label: {
                    ZStack {
                        if navigationSettings.followUser, navigationSettings.followHeading {
                            ImageLocationView(slash: false)
                            ImageConeView(slash: false)
                        } else if !navigationSettings.followUser, !navigationSettings.followHeading {
                            ImageLocationView(slash: true)
                            ImageConeView(slash: true)
                        } else if navigationSettings.followUser, !navigationSettings.followHeading {
                            ImageLocationView(slash: false)
                            ImageConeView(slash: true)
                        }
                    }
                    .foregroundStyle(.primary)
                    .frame(width: 12, height: 12)
                    .padding()
                    .glassEffect()
                }
                Button {
                    navigation.isSmall.toggle()
                } label: {
                    Image(systemName: minMaxButtonIcon())
                        .foregroundStyle(.primary)
                        .frame(width: 12, height: 12)
                        .padding()
                        .glassEffect()
                        .padding([.trailing], 10)
                }
            }
            .padding([.bottom], 7)
        }
    }
}

@available(iOS 26, *)
private struct MarkerLabel: View {
    @ObservedObject var navigation: Navigation
    let item: MKMapItem

    var body: some View {
        if let name = item.name {
            if let expectedTravelTime = navigation.route?.expectedTravelTime,
               item == navigation.destination
            {
                Text("\(name) (\(Duration.seconds(expectedTravelTime).format()))")
            } else {
                Text(name)
            }
        }
    }
}

@available(iOS 26, *)
private struct MapView: View {
    let model: Model
    @ObservedObject var navigationSettings: SettingsNavigation
    @ObservedObject var navigation: Navigation
    let metrics: GeometryProxy

    private func serLongPressLocation(coordinate: CLLocationCoordinate2D) {
        let placeDescriptor = PlaceDescriptor(representations: [.coordinate(coordinate)], commonName: nil)
        let request = MKMapItemRequest(placeDescriptor: placeDescriptor)
        Task {
            navigation.longPressLocation = try? await request.mapItem
            navigation.destination = nil
        }
    }

    private func mapSide(maximum: Double) -> Double {
        return min(maximum - 10, navigation.isSmall ? smallMapSide : maximumBigMapSide)
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $navigation.cameraPosition,
                interactionModes: [.pan, .rotate, .zoom],
                selection: $navigation.destination)
            {
                UserAnnotation()
                if let longPressLocation = navigation.longPressLocation {
                    Marker(coordinate: longPressLocation.location.coordinate) {
                        MarkerLabel(navigation: navigation, item: longPressLocation)
                    }
                    .tag(longPressLocation)
                }
                ForEach(navigation.searchResults, id: \.self) { searchResult in
                    Marker(coordinate: searchResult.location.coordinate) {
                        MarkerLabel(navigation: navigation, item: searchResult)
                    }
                }
                if let route = navigation.route {
                    MapPolyline(route)
                        .stroke(.blue, lineWidth: 5)
                }
            }
            .onMapCameraChange { context in
                navigation.cameraRegion = context.region
                if navigationSettings.followUser {
                    navigation.timer.startSingleShot(timeout: 5) {
                        navigation.updateCameraPosition(settings: navigationSettings)
                    }
                }
            }
            .frame(maxWidth: mapSide(maximum: metrics.size.width),
                   maxHeight: mapSide(maximum: metrics.size.height))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding([.trailing], 3)
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        guard case .second(true, let drag) = value else {
                            return
                        }
                        guard let location = drag?.location else {
                            return
                        }
                        guard let coordinate = proxy.convert(location, from: .local) else {
                            return
                        }
                        serLongPressLocation(coordinate: coordinate)
                    }
            )
        }
        .onChange(of: navigation.destination) { _ in
            navigation.updateDirections()
        }
        .onChange(of: navigationSettings.followUser) { _ in
            navigation.updateCameraPosition(settings: navigationSettings)
        }
        .onChange(of: navigationSettings.followHeading) { _ in
            navigation.updateCameraPosition(settings: navigationSettings)
        }
        .onAppear {
            if navigation.cameraRegion != nil {
                navigation.updateCameraPosition(settings: navigationSettings)
            } else {
                if let (latitude, longitude) = model.getLatestKnownLocation() {
                    let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    navigation.updateCameraPosition(settings: navigationSettings,
                                                    region: .init(center: center, span: span))
                }
            }
        }
    }
}

@available(iOS 26, *)
struct StreamOverlayNavigationView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var navigation: Navigation

    private func offset(metrics: GeometryProxy) -> Double {
        let offset: Double
        if database.bigButtons {
            offset = -(2 * segmentHeightBig + 10)
        } else {
            offset = -(2 * segmentHeight + 10)
        }
        if navigation.isSmall || metrics.size.height - offset > maximumBigMapSide {
            return offset
        } else {
            return 0
        }
    }

    var body: some View {
        GeometryReader { metrics in
            ZStack {
                HStack {
                    Spacer(minLength: 0)
                    VStack {
                        Spacer(minLength: 0)
                        MapView(model: model,
                                navigationSettings: model.database.navigation,
                                navigation: navigation,
                                metrics: metrics)
                    }
                }
                ControlsView(navigationSettings: model.database.navigation,
                             navigation: navigation,
                             metrics: metrics)
            }
            .offset(CGSize(width: 0, height: offset(metrics: metrics)))
        }
    }
}
