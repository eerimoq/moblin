import MapKit
import SwiftUI

private struct PrivacyRegionView: View {
    @EnvironmentObject var model: Model
    let region: SettingsPrivacyRegion
    @State var current: MKCoordinateRegion

    var body: some View {
        Map(coordinateRegion: $current)
            .aspectRatio(4 / 3, contentMode: .fill)
            .onChange(of: current) { _ in
                region.latitude = current.center.latitude
                region.longitude = current.center.longitude
                region.latitudeDelta = current.span.latitudeDelta
                region.longitudeDelta = current.span.longitudeDelta
            }
            .onDisappear {
                model.reloadLocation()
            }
    }
}

struct LocationSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var location: SettingsLocation
    @Binding var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $location.enabled)
                    .onChange(of: location.enabled) { _ in
                        model.reloadLocation()
                    }
            }
            if database.showAllSettings {
                Section {
                    Picker("Desired accuracy", selection: $location.desiredAccuracy) {
                        ForEach(SettingsLocationDesiredAccuracy.allCases, id: \.self) { accuracy in
                            Text(accuracy.toString())
                        }
                    }
                    .onChange(of: location.desiredAccuracy) { _ in
                        model.reloadLocation()
                    }
                    Picker("Distance filter", selection: $location.distanceFilter) {
                        ForEach(SettingsLocationDistanceFilter.allCases, id: \.self) { distanceFilter in
                            Text(distanceFilter.toString())
                        }
                    }
                    .onChange(of: location.distanceFilter) { _ in
                        model.reloadLocation()
                    }
                }
            }
            Section {
                Toggle("Reset when going live", isOn: $location.resetWhenGoingLive)
                TextButtonView("Reset") {
                    model.resetLocationData()
                }
            } header: {
                Text("Location data")
            } footer: {
                Text("Resets distance, average speed and slope.")
            }
            if database.showAllSettings, stream !== fallbackStream {
                Section {
                    NavigationLink {
                        StreamRealtimeIrlSettingsView(stream: stream)
                    } label: {
                        Toggle(isOn: $stream.realtimeIrlEnabled) {
                            Label("RealtimeIRL", systemImage: "dot.radiowaves.left.and.right")
                        }
                        .onChange(of: stream.realtimeIrlEnabled) { _ in
                            model.reloadLocation()
                        }
                    }
                } header: {
                    Text("Shortcut")
                }
            }
            Section {
                List {
                    ForEach(location.privacyRegions) { region in
                        PrivacyRegionView(region: region, current: MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude),
                            span: MKCoordinateSpan(
                                latitudeDelta: region.latitudeDelta,
                                longitudeDelta: region.longitudeDelta
                            )
                        ))
                    }
                    .onDelete { indexes in
                        location.privacyRegions.remove(atOffsets: indexes)
                        model.reloadLocation()
                    }
                }
                CreateButtonView {
                    let privacyRegion = SettingsPrivacyRegion()
                    if let (latitude, longitude) = model.getLatestKnownLocation() {
                        privacyRegion.latitude = latitude
                        privacyRegion.longitude = longitude
                        privacyRegion.latitudeDelta = 0.02
                        privacyRegion.longitudeDelta = 0.02
                    }
                    location.privacyRegions.append(privacyRegion)
                    model.reloadLocation()
                }
            } header: {
                Text("Privacy regions")
            } footer: {
                VStack(alignment: .leading) {
                    Text("Your location will not be shared with any service when within any privacy region.")
                    Text("")
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a privacy region"))
                }
            }
        }
        .navigationTitle("Location")
    }
}
