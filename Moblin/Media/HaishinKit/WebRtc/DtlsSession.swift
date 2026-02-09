import CryptoKit
import Foundation
import Network
import Security

private let dtlsQueue = DispatchQueue(label: "com.eerimoq.Moblin.webrtc.dtls")

enum DtlsState {
    case new
    case connecting
    case connected
    case closed
    case failed
}

protocol DtlsSessionDelegate: AnyObject {
    func dtlsSessionOnState(_ session: DtlsSession, state: DtlsState)
}

class DtlsSession {
    private let identity: SecIdentity
    private let certificate: SecCertificate
    let fingerprint: String
    private(set) var state: DtlsState = .new
    private var connection: NWConnection?
    private var srtpKeyingMaterial: Data?
    weak var delegate: DtlsSessionDelegate?

    init?() {
        let label = "com.eerimoq.Moblin.webrtc.dtls.\(UUID().uuidString)"
        guard let (identity, certificate) = DtlsSession.createIdentity(label: label) else {
            return nil
        }
        defer { DtlsSession.cleanupKeychain(label: label) }
        self.identity = identity
        self.certificate = certificate
        let certData = SecCertificateCopyData(certificate) as Data
        fingerprint = DtlsSession.computeFingerprintFromData(certData)
    }

    func start(host: String, port: UInt16) {
        dtlsQueue.async {
            self.startInternal(host: host, port: port)
        }
    }

    func stop() {
        dtlsQueue.async {
            self.stopInternal()
        }
    }

    func getSrtpKeyingMaterial() -> Data? {
        return dtlsQueue.sync {
            srtpKeyingMaterial
        }
    }

    private func startInternal(host: String, port: UInt16) {
        state = .connecting
        delegate?.dtlsSessionOnState(self, state: .connecting)
        let tlsOptions = NWProtocolTLS.Options()
        guard let secIdentity = sec_identity_create(identity) else {
            state = .failed
            delegate?.dtlsSessionOnState(self, state: .failed)
            return
        }
        sec_protocol_options_set_local_identity(
            tlsOptions.securityProtocolOptions,
            secIdentity
        )
        sec_protocol_options_set_min_tls_protocol_version(
            tlsOptions.securityProtocolOptions,
            .DTLSv12
        )
        sec_protocol_options_set_max_tls_protocol_version(
            tlsOptions.securityProtocolOptions,
            .DTLSv12
        )
        // Allow self-signed certificates from the remote peer
        sec_protocol_options_set_verify_block(
            tlsOptions.securityProtocolOptions,
            { _, _, completion in
                completion(true)
            },
            dtlsQueue
        )
        let params = NWParameters(dtls: tlsOptions, udp: .init())
        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            state = .failed
            delegate?.dtlsSessionOnState(self, state: .failed)
            return
        }
        connection = NWConnection(
            host: nwHost,
            port: nwPort,
            using: params
        )
        connection?.stateUpdateHandler = { [weak self] newState in
            dtlsQueue.async {
                self?.handleStateUpdate(newState)
            }
        }
        connection?.start(queue: dtlsQueue)
    }

    private func stopInternal() {
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        state = .closed
        srtpKeyingMaterial = nil
        delegate?.dtlsSessionOnState(self, state: .closed)
    }

    private func handleStateUpdate(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            state = .connected
            extractSrtpKeyingMaterial()
            delegate?.dtlsSessionOnState(self, state: .connected)
        case .failed:
            state = .failed
            connection?.cancel()
            connection = nil
            delegate?.dtlsSessionOnState(self, state: .failed)
        case .cancelled:
            state = .closed
            connection = nil
            delegate?.dtlsSessionOnState(self, state: .closed)
        default:
            break
        }
    }

    private func extractSrtpKeyingMaterial() {
        guard let metadata = connection?.metadata(definition: NWProtocolTLS.definition)
            as? NWProtocolTLS.Metadata
        else {
            return
        }
        sec_protocol_metadata_access_handle(
            metadata.securityProtocolMetadata
        ) { handle in
            // Extract 60 bytes of keying material for SRTP via RFC 5764:
            // client_write_key (16) + server_write_key (16) +
            // client_write_salt (14) + server_write_salt (14)
            var exportedData = Data(count: 60)
            let result = exportedData.withUnsafeMutableBytes { buffer in
                guard let baseAddress = buffer.baseAddress else {
                    return Int32(-1)
                }
                return "EXTRACTOR-dtls_srtp".withCString { label in
                    SSLExportKeyingMaterial(
                        handle,
                        label,
                        strlen(label),
                        nil,
                        0,
                        baseAddress,
                        60
                    )
                }
            }
            if result == 0 {
                srtpKeyingMaterial = exportedData
            }
        }
    }

    func send(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }

    static func computeFingerprintFromData(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        let hex = hash.map { String(format: "%02X", $0) }.joined(separator: ":")
        return "sha-256 \(hex)"
    }

    private static func createIdentity(label: String) -> (SecIdentity, SecCertificate)? {
        let keyParams: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrIsPermanent as String: false,
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyParams as CFDictionary, &error) else {
            return nil
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            return nil
        }
        guard let pubKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        let certBytes = buildSelfSignedCertificate(
            privateKey: privateKey,
            publicKeyData: pubKeyData
        )
        guard let certificate = SecCertificateCreateWithData(
            nil,
            Data(certBytes) as CFData
        ) else {
            return nil
        }
        // Store private key in keychain temporarily to create identity
        let addKeyParams: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecValueRef as String: privateKey,
            kSecAttrLabel as String: label,
            kSecAttrIsPermanent as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        guard SecItemAdd(addKeyParams as CFDictionary, nil) == errSecSuccess else {
            return nil
        }
        // Store certificate in keychain temporarily
        let addCertParams: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: label,
        ]
        guard SecItemAdd(addCertParams as CFDictionary, nil) == errSecSuccess else {
            return nil
        }
        // Retrieve the identity (private key + certificate pair)
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: label,
            kSecReturnRef as String: true,
        ]
        var identityResult: CFTypeRef?
        guard SecItemCopyMatching(
            identityQuery as CFDictionary,
            &identityResult
        ) == errSecSuccess else {
            return nil
        }
        guard let identity = identityResult as? SecIdentity else {
            return nil
        }
        return (identity, certificate)
    }

    private static func cleanupKeychain(label: String) {
        let deleteKeyParams: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrLabel as String: label,
        ]
        SecItemDelete(deleteKeyParams as CFDictionary)
        let deleteCertParams: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: label,
        ]
        SecItemDelete(deleteCertParams as CFDictionary)
    }

    private static func buildSelfSignedCertificate(
        privateKey: SecKey,
        publicKeyData: Data
    ) -> [UInt8] {
        let serialNumber: [UInt8] = [0x02, 0x01, 0x01]
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
        let ecOid: [UInt8] = [0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01]
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

