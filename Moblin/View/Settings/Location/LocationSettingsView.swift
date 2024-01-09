import SwiftUI

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
            if model.isLocationEnabled() {
                Section {
                    Text("Latitude: \(model.latestLocation.coordinate.latitude)")
                    Text("Longitude: \(model.latestLocation.coordinate.longitude)")
                    Text("Speed: \(formatOneDecimal(value: Float(model.latestLocation.speed))) m/s")
                    Text("Altitude: \(formatOneDecimal(value: Float(model.latestLocation.altitude))) m")
                }
            }
        }
        .navigationTitle("Location")
        .toolbar {
            SettingsToolbar()
        }
    }
}
