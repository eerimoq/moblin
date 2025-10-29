import GeoToolbox
import MapKit
import SwiftUI

private let smallMapSide = 200.0

@available(iOS 26, *)
private struct ControlsView: View {
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

    private func minMaxButtonIcon() -> String {
        if navigation.isSmall {
            return "arrow.up.left.and.arrow.down.right"
        } else {
            return "arrow.down.right.and.arrow.up.left"
        }
    }

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if !navigation.isSmall {
                    TextField("What are you looking for?", text: $navigation.searchText)
                        .frame(maxWidth: 300, maxHeight: 20)
                        .padding(12)
                        .glassEffect()
                        .onSubmit {
                            search(text: navigation.searchText)
                        }
                }
                Button {
                    navigation.isSmall.toggle()
                } label: {
                    Image(systemName: minMaxButtonIcon())
                        .foregroundColor(.primary)
                        .frame(width: 12, height: 12)
                        .padding()
                        .glassEffect()
                        .padding(2)
                }
                .padding(7)
            }
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

    private func destinationChanged() {
        guard let destination = navigation.destination else {
            return
        }
        navigation.route = nil
        let request = MKDirections.Request()
        request.source = .forCurrentLocation()
        request.destination = destination
        request.transportType = .walking
        let directions = MKDirections(request: request)
        directions.calculate { response, _ in
            guard let response else {
                return
            }
            navigation.route = response.routes.first
        }
    }

    private func mapSide(bigSide: Double) -> Double {
        if navigation.isSmall {
            return smallMapSide
        } else {
            return bigSide - 10
        }
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $navigation.cameraPosition, selection: $navigation.destination) {
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
            }
            .frame(maxWidth: mapSide(bigSide: metrics.size.width),
                   maxHeight: mapSide(bigSide: metrics.size.height))
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
            destinationChanged()
        }
        .onAppear {
            if let cameraRegion = navigation.cameraRegion {
                navigation.cameraPosition = .region(cameraRegion)
            } else {
                if let (latitude, longitude) = model.getLatestKnownLocation() {
                    let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    navigation.cameraPosition = .region(.init(center: center, span: span))
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

    private func offset() -> Double {
        if navigation.isSmall {
            if database.bigButtons {
                return -(2 * segmentHeightBig + 10)
            } else {
                return -(2 * segmentHeight + 10)
            }
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
                        MapView(model: model, navigation: navigation, metrics: metrics)
                    }
                }
                ControlsView(navigation: navigation)
            }
            .offset(CGSize(width: 0, height: offset()))
        }
    }
}
