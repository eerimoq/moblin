import SwiftUI

struct ChatTextToSpeechSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechDetectLanguagePerMessage!
                }, set: { value in
                    model.database.chat.textToSpeechDetectLanguagePerMessage = value
                    model.store()
                })) {
                    Text("Detect language per message")
                }
                Toggle(isOn: Binding(get: {
                    model.database.chat.textToSpeechSayUsername!
                }, set: { value in
                    model.database.chat.textToSpeechSayUsername = value
                    model.store()
                })) {
                    Text("Say username")
                }
                HStack {
                    Text("Preferred gender")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        model.database.chat.textToSpeechGender!.toString()
                    }, set: { value in
                        model.database.chat.textToSpeechGender = SettingsGender.fromString(value: value)
                        switch model.database.chat.textToSpeechGender {
                        case .male:
                            model.sayGender = .male
                        case .female:
                            model.sayGender = .female
                        default:
                            model.sayGender = nil
                        }
                        model.store()
                        model.objectWillChange.send()
                    })) {
                        ForEach(genders, id: \.self) {
                            Text($0)
                        }
                    }
                }
            }
        }
        .navigationTitle("Text to speech")
        .toolbar {
            SettingsToolbar()
        }
    }
}
