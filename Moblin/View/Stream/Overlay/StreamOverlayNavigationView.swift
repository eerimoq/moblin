import GeoToolbox
import MapKit
import SwiftUI

private let smallMapSide = 200.0

@available(iOS 26, *)
private struct MapSizeButtonView: View {
    @Binding var isSmall: Bool
    @Binding var cameraRegion: MKCoordinateRegion?
    @Binding var searchResults: [MKMapItem]
    @State var searchText: String = ""

    private func search(text: String) {
        guard let cameraRegion, !text.isEmpty else {
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
            searchResults = response.mapItems
        }
    }

    private func minMaxButtonIcon() -> String {
        if isSmall {
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
                if !isSmall {
                    TextField("What are you looking for?", text: $searchText)
                        .frame(maxWidth: 300, maxHeight: 20)
                        .padding(12)
                        .glassEffect()
                        .onSubmit {
                            search(text: searchText)
                        }
                        .onChange(of: searchText) { _ in
                            if searchText.isEmpty {
                                searchResults.removeAll()
                            }
                        }
                }
                Button {
                    isSmall.toggle()
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
struct StreamOverlayNavigationView: View {
    @ObservedObject var database: Database
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var cameraRegion: MKCoordinateRegion?
    @State private var route: MKRoute?
    @State private var isSmall = true
    @State private var destination: MKMapItem?
    @State private var longPressLocation: MKMapItem?
    @State private var searchResults: [MKMapItem] = []

    private func offset() -> Double {
        if isSmall {
            if database.bigButtons {
                return -(2 * segmentHeightBig + 10)
            } else {
                return -(2 * segmentHeight + 10)
            }
        } else {
            return 0
        }
    }

    private func serLongPressLocation(coordinate: CLLocationCoordinate2D) {
        let placeDescriptor = PlaceDescriptor(representations: [.coordinate(coordinate)], commonName: nil)
        let request = MKMapItemRequest(placeDescriptor: placeDescriptor)
        Task {
            longPressLocation = try? await request.mapItem
            destination = longPressLocation
        }
    }

    private func destinationChanged() {
        if let destination {
            let request = MKDirections.Request()
            request.source = .forCurrentLocation()
            request.destination = destination
            request.transportType = .walking
            let directions = MKDirections(request: request)
            directions.calculate { response, _ in
                guard let response else {
                    return
                }
                route = response.routes.first
            }
        } else {
            route = nil
        }
    }

    var body: some View {
        GeometryReader { metrics in
            ZStack {
                HStack {
                    Spacer(minLength: 0)
                    VStack {
                        Spacer(minLength: 0)
                        MapReader { proxy in
                            Map(position: $cameraPosition, selection: $destination) {
                                UserAnnotation()
                                if let longPressLocation {
                                    Marker(item: longPressLocation)
                                }
                                ForEach(searchResults, id: \.self) { searchResult in
                                    Marker(item: searchResult)
                                }
                                if let route {
                                    MapPolyline(route)
                                        .stroke(.blue, lineWidth: 5)
                                }
                            }
                            .onMapCameraChange { context in
                                cameraRegion = context.region
                            }
                            .frame(maxWidth: isSmall ? smallMapSide : metrics.size.width - 10,
                                   maxHeight: isSmall ? smallMapSide : metrics.size.height - 10)
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
                    }
                }
                MapSizeButtonView(isSmall: $isSmall,
                                  cameraRegion: $cameraRegion,
                                  searchResults: $searchResults)
            }
            .offset(CGSize(width: 0, height: offset()))
        }
        .onChange(of: destination) { _ in
            destinationChanged()
        }
    }
}
