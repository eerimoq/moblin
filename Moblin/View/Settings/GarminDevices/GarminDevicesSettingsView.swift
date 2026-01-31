import SwiftUI

struct GarminDevicesSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var garminDevices: SettingsGarminDevices
    @ObservedObject var garminUnits: SettingsGarminUnits

    var body: some View {
        Form {
            Section("Units") {
                Picker("Pace unit", selection: $garminUnits.paceUnit) {
                    ForEach(SettingsGarminPaceUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue)
                            .tag(unit)
                    }
                }
                Picker("Distance unit", selection: $garminUnits.distanceUnit) {
                    ForEach(SettingsGarminDistanceUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue)
                            .tag(unit)
                    }
                }
            }
            Section {
                List {
                    ForEach(garminDevices.devices) { device in
                        GarminDeviceSettingsView(model: model,
                                                 garminDevices: garminDevices,
                                                 device: device,
                                                 status: model.statusTopRight)
                    }
                    .onDelete { offsets in
                        garminDevices.devices.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    let device = SettingsGarminDevice()
                    device.name = makeUniqueName(name: SettingsGarminDevice.baseName,
                                                 existingNames: garminDevices.devices)
                    garminDevices.devices.append(device)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("Garmin devices")
    }
}
