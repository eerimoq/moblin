import CryptoKit
import Foundation
import Security

private let dtlsQueue = DispatchQueue(label: "com.eerimoq.Moblin.webrtc.dtls")

enum DtlsState {
    case new
    case connecting
    case connected
    case closed
    case failed
}

enum DtlsRole {
    case client
    case server
}

protocol DtlsSessionDelegate: AnyObject {
    func dtlsSessionOnState(_ session: DtlsSession, state: DtlsState)
    func dtlsSessionOnSend(_ session: DtlsSession, data: Data)
}

class DtlsSession {
    private let privateKey: SecKey
    private let certificateData: Data
    let fingerprint: String
    private(set) var state: DtlsState = .new
    private(set) var role: DtlsRole = .client
    private var srtpKeyingMaterial: Data?
    weak var delegate: DtlsSessionDelegate?

    init?() {
        let keyParams: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrIsPermanent as String: false,
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(keyParams as CFDictionary, &error) else {
            return nil
        }
        privateKey = key
        guard let publicKey = SecKeyCopyPublicKey(key) else {
            return nil
        }
        guard let pubKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        let certBytes = DtlsSession.buildSelfSignedCertificate(
            privateKey: key,
            publicKeyData: pubKeyData
        )
        certificateData = Data(certBytes)
        fingerprint = DtlsSession.computeFingerprintFromData(certificateData)
    }

    func setRole(_ role: DtlsRole) {
        dtlsQueue.async {
            self.role = role
        }
    }

    func start() {
        dtlsQueue.async {
            self.startInternal()
        }
    }

    func stop() {
        dtlsQueue.async {
            self.stopInternal()
        }
    }

    func handleIncomingData(_ data: Data) {
        dtlsQueue.async {
            self.handleIncomingDataInternal(data)
        }
    }

    func getSrtpKeyingMaterial() -> Data? {
        return dtlsQueue.sync {
            srtpKeyingMaterial
        }
    }

    private func startInternal() {
        state = .connecting
        delegate?.dtlsSessionOnState(self, state: .connecting)
    }

    private func stopInternal() {
        state = .closed
        srtpKeyingMaterial = nil
        delegate?.dtlsSessionOnState(self, state: .closed)
    }

    private func handleIncomingDataInternal(_: Data) {
        // DTLS record processing will be implemented with full handshake support.
    }

    static func computeFingerprintFromData(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        let hex = hash.map { String(format: "%02X", $0) }.joined(separator: ":")
        return "sha-256 \(hex)"
    }

    private static func buildSelfSignedCertificate(
        privateKey: SecKey,
        publicKeyData: Data
    ) -> [UInt8] {
        let serialNumber: [UInt8] = [0x02, 0x01, 0x01]
        // SHA256 with ECDSA OID: 1.2.840.10045.4.3.2
        let signatureAlgorithm: [UInt8] = [
            0x30, 0x0A,
            0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02,
        ]
        let issuer = buildSubjectName("Moblin WebRTC")
        let subject = issuer
        let notBefore: [UInt8] = [0x17, 0x0D] + Array("250101000000Z".utf8)
        let notAfter: [UInt8] = [0x17, 0x0D] + Array("350101000000Z".utf8)
        let validity: [UInt8] = [0x30] + derLength(notBefore.count + notAfter.count) +
            notBefore + notAfter
        // EC public key OID: 1.2.840.10045.2.1
        let ecOid: [UInt8] = [0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01]
        // P-256 curve OID: 1.2.840.10045.3.1.7
        let p256Oid: [UInt8] = [0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07]
        let algId: [UInt8] = [0x30] + derLength(ecOid.count + p256Oid.count) + ecOid + p256Oid
        let pubKeyBytes = Array(publicKeyData)
        let pubKeyBitString: [UInt8] = [0x03] + derLength(pubKeyBytes.count + 1) +
            [0x00] + pubKeyBytes
        let subjectPublicKeyInfo: [UInt8] = [0x30] +
            derLength(algId.count + pubKeyBitString.count) + algId + pubKeyBitString
        let version: [UInt8] = [0xA0, 0x03, 0x02, 0x01, 0x02]
        let tbsContent = version + serialNumber + signatureAlgorithm + issuer + validity +
            subject + subjectPublicKeyInfo
        let tbsCertificate: [UInt8] = [0x30] + derLength(tbsContent.count) + tbsContent
        // Sign TBS certificate with the private key using ECDSA-SHA256
        let signatureBytes = signData(Data(tbsCertificate), with: privateKey)
        let signatureValue: [UInt8] = [0x03] + derLength(signatureBytes.count + 1) +
            [0x00] + signatureBytes
        let certContent = tbsCertificate + signatureAlgorithm + signatureValue
        let certificate: [UInt8] = [0x30] + derLength(certContent.count) + certContent
        return certificate
    }

    private static func signData(_ data: Data, with privateKey: SecKey) -> [UInt8] {
        let algorithm = SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            return []
        }
        guard let signature = SecKeyCreateSignature(
            privateKey,
            algorithm,
            data as CFData,
            nil
        ) as Data? else {
            return []
        }
        return Array(signature)
    }
}

private func buildSubjectName(_ commonName: String) -> [UInt8] {
    let cnBytes = Array(commonName.utf8)
    let cnValueLen = cnBytes.count
    let oid: [UInt8] = [0x55, 0x04, 0x03]
    let cnValue: [UInt8] = [0x0C] + derLength(cnValueLen) + cnBytes
    let attrTypeAndValue: [UInt8] = [0x30] + derLength(oid.count + 2 + cnValue.count) +
        [0x06, UInt8(oid.count)] + oid + cnValue
    let rdn: [UInt8] = [0x31] + derLength(attrTypeAndValue.count) + attrTypeAndValue
    let name: [UInt8] = [0x30] + derLength(rdn.count) + rdn
    return name
}

private func derLength(_ length: Int) -> [UInt8] {
    if length < 128 {
        return [UInt8(length)]
    } else if length < 256 {
        return [0x81, UInt8(length)]
    } else {
        return [0x82, UInt8(length >> 8), UInt8(length & 0xFF)]
    }
}
