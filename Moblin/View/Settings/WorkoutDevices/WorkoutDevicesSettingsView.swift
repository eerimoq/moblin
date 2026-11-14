import SwiftUI

struct WorkoutDevicesSettingsView: View {
    let model: Model
    @ObservedObject var workoutDevices: SettingsWorkoutDevices

    var body: some View {
        Form {
            Section {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Image("HeartRateDevice")
                            .resizable()
                            .aspectRatio(955 / 500, contentMode: .fit)
                            .layoutPriority(1)
                        Image("HeartRateDeviceCoros")
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                    }
                    .aspectRatio(955 / 500 + 1, contentMode: .fit)
                    Image("CyclingPowerDevice")
                        .resizable()
                        .scaledToFit()
                }
                .aspectRatio(1 / (500 / 1455 + 500 / 931), contentMode: .fit)
                .integrationImageRow(height: 180)
            }
            Section {
                List {
                    ForEach(workoutDevices.devices) { device in
                        WorkoutDeviceSettingsView(model: model,
                                                  workoutDevices: workoutDevices,
                                                  device: device,
                                                  status: model.statusTopRight)
                            .contextMenuDeleteButton {
                                workoutDevices.devices.removeAll { $0.id == device.id }
                            }
                    }
                    .onDelete { offsets in
                        workoutDevices.devices.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    let device = SettingsWorkoutDevice()
                    device.name = makeUniqueName(name: SettingsWorkoutDevice.baseName,
                                                 existingNames: workoutDevices.devices)
                    workoutDevices.devices.append(device)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a device"))
            }
        }
        .navigationTitle("Workout devices")
    }
}
