import ShazamKit

class MusicIdentifier: NSObject {
    private let session = SHSession()

    override init() {
        super.init()
        session.delegate = self
    }

    func identify(buffers: [AVAudioPCMBuffer]) throws {
        let signatureGenerator = SHSignatureGenerator()
        for buffer in buffers {
            try signatureGenerator.append(buffer, at: nil)
        }
        let signature = signatureGenerator.signature()
        session.match(signature)
    }
}

extension MusicIdentifier: SHSessionDelegate {
    func session(_: SHSession, didFind match: SHMatch) {
        logger.info("music-identifier: Found \(match)")
    }

    func session(_: SHSession, didNotFindMatchFor _: SHSignature, error _: Error?) {
        logger.info("music-identifier: No match")
    }
}
