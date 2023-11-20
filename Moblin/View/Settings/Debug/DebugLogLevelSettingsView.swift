import SwiftUI

struct DebugLogLevelSettingsView: View {
    @EnvironmentObject var model: Model
    @State var level: String

    var body: some View {
        Form {
            Section {
                Picker("", selection: $level) {
                    ForEach(logLevels, id: \.self) { level in
                        Text(level)
                    }
                }
                .onChange(of: level) { level in
                    guard let level = SettingsLogLevel(rawValue: level) else {
                        return
                    }
                    logger.debugEnabled = level == .debug
                    model.database.debug!.logLevel = level
                    model.store()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Log Level")
        .toolbar {
            SettingsToolbar()
        }
    }
}
