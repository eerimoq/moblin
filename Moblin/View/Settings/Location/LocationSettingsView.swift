import MapKit
import SwiftUI

struct PrivacyRegionView: View {
    @EnvironmentObject var model: Model
    var region: SettingsPrivacyRegion
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
                model.store()
                model.reloadLocation()
            }
    }
}

struct LocationSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    model.database.location!.enabled
                }, set: { value in
                    model.database.location!.enabled = value
                    model.store()
                    model.reloadLocation()
                }))
            }
            Section {
                List {
                    ForEach(model.database.location!.privacyRegions) { region in
                        PrivacyRegionView(region: region, current: MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: region.latitude,
                                                           longitude: region.longitude),
                            span: MKCoordinateSpan(
                                latitudeDelta: region.latitudeDelta,
                                longitudeDelta: region.longitudeDelta
                            )
                        ))
                    }
                    .onDelete(perform: { indexes in
                        model.database.location!.privacyRegions.remove(atOffsets: indexes)
                        model.store()
                        model.reloadLocation()
                    })
                }
                CreateButtonView(action: {
                    model.database.location!.privacyRegions.append(SettingsPrivacyRegion())
                    model.store()
                    model.objectWillChange.send()
                    model.reloadLocation()
                })
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
        .toolbar {
            SettingsToolbar()
        }
    }
}
