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
}

extension Model: SpeechToTextDelegate {
    func speechToTextPartialStart(position: Int, frozenText: String) {
        speechToTextInfo.latestPosition = position
        speechToTextInfo.latestFrozenText = frozenText
        if #available(iOS 26.0, *) {
            for translator in Translator.translators {
                translator.partialStart()
            }
        }
    }

    func speechToTextPartialResult(partialText: String) {
        speechToTextInfo.latestPartialText = partialText
        if #available(iOS 26.0, *) {
            for translator in Translator.translators {
                translator.partialResult(partialText: partialText)
            }
        }
    }

    func speechToTextProcess() {
        if #available(iOS 26.0, *) {
            for translator in Translator.translators {
                translator.translate()
            }
        }
        guard let position = speechToTextInfo.latestPosition,
              let frozenText = speechToTextInfo.latestFrozenText,
              let partialText = speechToTextInfo.latestPartialText
        else {
            return
        }
        speechToTextInfo.latestPartialText = nil
        let text = frozenText + partialText
        speechToTextPartialResultTextWidgets(position: position, text: text, languageIdentifier: nil)
        speechToTextPartialResultAlertsWidget(text: text)
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

extension Model: TranslatorDelegate {
    func translatorTranslated(languageIdentifier: String, position: Int, text: String) {
        speechToTextPartialResultTextWidgets(position: position, text: text, languageIdentifier: languageIdentifier)
    }
}

private protocol TranslatorDelegate: AnyObject {
    func translatorTranslated(languageIdentifier: String, position: Int, text: String)
}

@available(iOS 26.0, *)
private class Translator {
    static var translators: [Translator] = []

    private let session: TranslationSession
    private var ready = true
    private var latestText: String?
    private let targetIdentifier: String
    private var position = 0
    private var frozenText: String = ""
    private var latestPartialText: String = ""
    weak var delegate: TranslatorDelegate?

    init(targetIdentifier: String) {
        self.targetIdentifier = targetIdentifier
        session = TranslationSession(installedSource: Locale.current.language,
                                     target: .init(identifier: targetIdentifier))
    }

    func partialStart() {
        frozenText += latestPartialText
        latestPartialText = ""
    }

    func partialResult(partialText: String) {
        latestPartialText = partialText
        latestText = frozenText + latestPartialText
    }

    func translate() {
        guard ready else {
            return
        }
        ready = false
        Task { @MainActor in
            while let text = latestText {
                latestText = nil
                do {
                    let response = try await session.translate(text)
                    delegate?.translatorTranslated(languageIdentifier: targetIdentifier,
                                                   position: position,
                                                   text: response.targetText)
                } catch let error as TranslationError {
                    let message = error.failureReason ?? error.localizedDescription
                    delegate?.translatorTranslated(languageIdentifier: targetIdentifier,
                                                   position: position,
                                                   text: message)
                } catch {
                    logger.info("speech-to-text: Translation error: \(error)")
                }
            }
            ready = true
        }
    }
}
