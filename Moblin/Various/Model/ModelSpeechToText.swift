import Foundation

extension Model {
    func reloadSpeechToText() {
        speechToText.stop()
        speechToText = SpeechToText()
        speechToText.delegate = self
        for textEffect in textEffects.values {
            textEffect.clearSubtitles()
        }
        if isSpeechToTextNeeded() {
            speechToText.start { message in
                self.makeErrorToast(title: message)
            }
        }
    }

    func isSpeechToTextNeeded() -> Bool {
        for widget in widgetsInCurrentScene(onlyEnabled: true) {
            switch widget.type {
            case .text:
                if widget.text.needsSubtitles {
                    return true
                }
            case .alerts:
                if widget.alerts.needsSubtitles! {
                    return true
                }
            default:
                break
            }
        }
        return false
    }
}

extension Model: SpeechToTextDelegate {
    func speechToTextPartialResult(position: Int, text: String) {
        speechToTextPartialResultTextWidgets(position: position, text: text)
        speechToTextPartialResultAlertsWidget(text: text)
    }

    private func speechToTextPartialResultTextWidgets(position: Int, text: String) {
        for textEffect in textEffects.values {
            textEffect.updateSubtitles(position: position, text: text)
        }
    }

    private func speechToTextPartialResultAlertsWidget(text: String) {
        guard text.count > speechToTextAlertMatchOffset else {
            return
        }
        let startMatchIndex = text.index(text.startIndex, offsetBy: speechToTextAlertMatchOffset)
        for alertEffect in enabledAlertsEffects {
            let settings = alertEffect.getSettings().speechToText!
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
                DispatchQueue.main.async {
                    self.playAlert(alert: .speechToTextString(string.id))
                }
            }
        }
    }

    func speechToTextClear() {
        for textEffect in textEffects.values {
            textEffect.clearSubtitles()
        }
        speechToTextAlertMatchOffset = 0
    }
}
