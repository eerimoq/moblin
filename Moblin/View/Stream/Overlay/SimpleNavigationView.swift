import GeoToolbox
import MapKit
import SwiftUI

private let smallMapSide = 200.0

@available(iOS 26, *)
private struct MapSizeButtonView: View {
    @Binding var showing: Bool

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                Button {
                    showing.toggle()
                } label: {
                    Image(systemName: showing ? "arrow.down.right.and.arrow.up.left" :
                        "arrow.up.left.and.arrow.down.right")
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
struct SimpleNavigationView: View {
    @ObservedObject var database: Database
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var route: MKRoute?
    @State private var isSmall = true
    @State private var destination: MKMapItem?

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

    private func setDestination(coordinate: CLLocationCoordinate2D) {
        let placeDescriptor = PlaceDescriptor(representations: [.coordinate(coordinate)], commonName: nil)
        let request = MKMapItemRequest(placeDescriptor: placeDescriptor)
        Task {
            destination = try? await request.mapItem
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
                                if let destination {
                                    Marker(item: destination)
                                }
                                if let route {
                                    MapPolyline(route)
                                        .stroke(.blue, lineWidth: 5)
                                }
                            }
                            .frame(maxWidth: isSmall ? smallMapSide : metrics.size.width - 10,
                                   maxHeight: isSmall ? smallMapSide : metrics.size.height - 10)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .padding([.trailing], 3)
                            .onTapGesture {
                                destination = nil
                            }
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
                                        setDestination(coordinate: coordinate)
                                    }
                            )
                        }
                    }
                }
                MapSizeButtonView(showing: $isSmall)
            }
            .offset(CGSize(width: 0, height: offset()))
        }
        .onChange(of: destination) { _ in
            destinationChanged()
        }
    }
}
