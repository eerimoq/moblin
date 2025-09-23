import Translation

protocol TranslatorDelegate: AnyObject {
    func translatorTranslated(languageIdentifier: String, text: String)
}

@available(iOS 26.0, *)
class Translator {
    static var translators: [Translator] = []

    private let session: TranslationSession
    private var ready = true
    private var latestText: String?
    private let targetIdentifier: String
    weak var delegate: TranslatorDelegate?

    init(targetIdentifier: String) {
        self.targetIdentifier = targetIdentifier
        session = TranslationSession(installedSource: Locale.current.language,
                                     target: .init(identifier: targetIdentifier))
    }

    func translate(text: String) {
        latestText = text
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
                                                   text: response.targetText)
                } catch let error as TranslationError {
                    let message = error.failureReason ?? error.localizedDescription
                    delegate?.translatorTranslated(languageIdentifier: targetIdentifier, text: message)
                } catch {
                    logger.info("speech-to-text: Translation error: \(error)")
                }
            }
            ready = true
        }
    }
}
