import AVFAudio
import SwiftUI

private func localize(_ languageCode: String) -> String {
    return NSLocale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
}

private struct LanguageView: View {
    var languageCode: String
    @State var voice: String
    var onVoiceChange: (String, String) -> Void

    private func voices(language: String) -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter { $0.language.prefix(2) == language }
    }

    var body: some View {
        Form {
            Picker("", selection: $voice) {
                ForEach(voices(language: languageCode), id: \.identifier) { voice in
                    let emote = emojiFlag(country: Locale(identifier: voice.language).region?
                        .identifier ?? "")
                    Text("\(emote) \(voice.name)")
                        .tag(voice.identifier)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .onChange(of: voice) { _ in
                onVoiceChange(languageCode, voice)
            }
        }
        .navigationTitle(localize(languageCode))
    }
}

private struct Language {
    let name: String
    let code: String
    let selectedVoiceIdentifier: String
    let selectedVoiceName: String
}

struct VoicesView: View {
    var textToSpeechLanguageVoices: [String: String]
    var onVoiceChange: (String, String) -> Void

    private func languages() -> [Language] {
        var languages: [Language] = []
        var seen: Set<String> = []
        let voices = AVSpeechSynthesisVoice.speechVoices()
        for voice in voices {
            let code = String(voice.language.prefix(2))
            guard !seen.contains(code) else {
                continue
            }
            let selectedVoiceIdentifier = textToSpeechLanguageVoices[code] ?? ""
            let selectedVoiceName = voices.first(where: { $0.identifier == selectedVoiceIdentifier })?
                .name ?? ""
            languages.append(.init(name: localize(voice.language),
                                   code: code,
                                   selectedVoiceIdentifier: selectedVoiceIdentifier,
                                   selectedVoiceName: selectedVoiceName))
            seen.insert(code)
        }
        return languages
    }

    var body: some View {
        Form {
            ForEach(languages(), id: \.code) { language in
                NavigationLink(destination: LanguageView(
                    languageCode: language.code,
                    voice: language.selectedVoiceIdentifier,
                    onVoiceChange: onVoiceChange
                )) {
                    HStack {
                        Text(language.name)
                        Spacer()
                        Text(language.selectedVoiceName)
                    }
                }
            }
        }
        .navigationTitle("Voices")
    }
}
