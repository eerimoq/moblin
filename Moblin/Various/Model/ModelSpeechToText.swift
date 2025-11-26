import Foundation
import Translation

extension Model {
    func reloadSpeechToText() {
        stopSpeechToText()
        if isSpeechToTextNeeded() {
            startSpeechToText()
        }
    }

    func startSpeechToText() {
        speechToText = SpeechToText()
        speechToText?.delegate = self
        speechToText?.start { message in
            self.makeErrorToast(title: message)
        }
        for widget in widgetsInCurrentScene(onlyEnabled: true) {
            switch widget.widget.type {
            case .text:
                let languageIdentifiers = Set(widget.widget.text.subtitles.map { $0.identifier })
                for languageIdentifier in languageIdentifiers {
                    if let languageIdentifier {
                        addTranslator(targetIdentifier: languageIdentifier)
                    }
                }
            default:
                break
            }
        }
    }

    func stopSpeechToText() {
        removeAllTranslators()
        speechToText?.stop()
        speechToText = nil
        for textEffect in textEffects.values {
            textEffect.clearSubtitles()
        }
        speechToTextTextAligners.removeAll()
    }

    func updateSpeechToText() {
        if isSpeechToTextNeeded() {
            if speechToText == nil {
                startSpeechToText()
            }
        } else if speechToText != nil {
            stopSpeechToText()
        }
    }

    func isSpeechToTextNeeded() -> Bool {
        for widget in widgetsInCurrentScene(onlyEnabled: true) {
            switch widget.widget.type {
            case .text:
                if widget.widget.text.needsSubtitles {
                    return true
                }
            case .alerts:
                if widget.widget.alerts.needsSubtitles {
                    return true
                }
            default:
                break
            }
        }
        return false
    }

    func speechToTextClear() {
        for textEffect in textEffects.values {
            textEffect.clearSubtitles()
        }
        speechToTextTextAligners.removeAll()
        speechToTextAlertMatchOffset = 0
    }

    private func removeAllTranslators() {
        guard #available(iOS 26.0, *) else {
            return
        }
        Translator.translators.removeAll()
    }

    private func addTranslator(targetIdentifier: String) {
        guard #available(iOS 26.0, *) else {
            return
        }
        let translator = Translator(targetIdentifier: targetIdentifier)
        translator.delegate = self
        Translator.translators.append(translator)
    }

    private func speechToTextPartialResultTextWidgets(position: Int, text: String, languageIdentifier: String?) {
        for textEffect in textEffects.values {
            textEffect.updateSubtitles(position: position, text: text, languageIdentifier: languageIdentifier)
        }
    }

    private func speechToTextPartialResultAlertsWidget(text: String) {
        guard text.count > speechToTextAlertMatchOffset else {
            return
        }
        let startMatchIndex = text.index(text.startIndex, offsetBy: speechToTextAlertMatchOffset)
        for alertEffect in enabledAlertsEffects {
            let settings = alertEffect.getSettings().speechToText
            for string in settings.strings where string.alert.enabled {
                guard let matchRange = text.range(
                    of: string.string,
                    options: .caseInsensitive,
                    range: startMatchIndex ..< text.endIndex
                ) else {
                    continue
                }
                let offset = text.distance(from: text.startIndex, to: matchRange.upperBound)
                if offset > speechToTextAlertMatchOffset {
                    speechToTextAlertMatchOffset = offset
                }
                self.playAlert(alert: .speechToTextString(string.id))
            }
        }
    }
}

extension Model: SpeechToTextDelegate {
    func speechToTextPartialResult(position: Int, text: String) {
        speechToTextLatestPosition = position
        speechToTextLatestText = text
    }

    func speechToTextProcess() {
        guard let position = speechToTextLatestPosition, let text = speechToTextLatestText else {
            return
        }
        speechToTextLatestPosition = nil
        speechToTextLatestText = nil
        if #available(iOS 26.0, *) {
            for translator in Translator.translators {
                translator.translate(text: String(text.suffix(150)))
            }
        }
        speechToTextPartialResultTextWidgets(position: position, text: text, languageIdentifier: nil)
        speechToTextPartialResultAlertsWidget(text: text)
    }
}

extension Model: TranslatorDelegate {
    func translatorTranslated(languageIdentifier: String, text: String) {
        let position: Int
        if let textAligner = speechToTextTextAligners[languageIdentifier] {
            textAligner.update(text: text)
            position = textAligner.position
        } else {
            let textAligner = TextAligner(text: text)
            speechToTextTextAligners[languageIdentifier] = textAligner
            position = textAligner.position
        }
        speechToTextPartialResultTextWidgets(position: position, text: text, languageIdentifier: languageIdentifier)
    }
}
