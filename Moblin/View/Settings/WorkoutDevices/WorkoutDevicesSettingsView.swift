import SwiftUI

struct WorkoutDevicesSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var workoutDevices: SettingsWorkoutDevices

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "HeartRateDevice")
                    Image("HeartRateDeviceCoros")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(.white)
                        .frame(height: 102)
                }
            }
            Section {
                List {
                    ForEach(workoutDevices.devices) { device in
                        WorkoutDeviceSettingsView(model: model,
                                                  workoutDevices: workoutDevices,
                                                  device: device,
                                                  status: model.statusTopRight)
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
