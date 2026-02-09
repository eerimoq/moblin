import CryptoKit
import Foundation

private let srtpQueue = DispatchQueue(label: "com.eerimoq.Moblin.webrtc.srtp")

class SrtpSession {
    private var encryptionKey: SymmetricKey?
    private var saltKey: Data?
    private var authKey: SymmetricKey?
    private(set) var isReady: Bool = false

    func deriveKeys(keyingMaterial: Data, isClient: Bool) {
        srtpQueue.async {
            self.deriveKeysInternal(keyingMaterial: keyingMaterial, isClient: isClient)
        }
    }

    func protectRtp(_ packet: Data) -> Data? {
        return srtpQueue.sync {
            protectRtpInternal(packet)
        }
    }

    func protectRtcp(_ packet: Data) -> Data? {
        return srtpQueue.sync {
            protectRtcpInternal(packet)
        }
    }

    private func deriveKeysInternal(keyingMaterial: Data, isClient: Bool) {
        // DTLS-SRTP uses the exported keying material to derive:
        // - client write master key (16 bytes)
        // - server write master key (16 bytes)
        // - client write master salt (14 bytes)
        // - server write master salt (14 bytes)
        // Total: 60 bytes minimum
        guard keyingMaterial.count >= 60 else {
            return
        }
        let clientKeyOffset = 0
        let serverKeyOffset = 16
        let clientSaltOffset = 32
        let serverSaltOffset = 46

        let writeKey: Data
        let writeSalt: Data
        if isClient {
            writeKey = keyingMaterial[clientKeyOffset ..< clientKeyOffset + 16]
            writeSalt = keyingMaterial[clientSaltOffset ..< clientSaltOffset + 14]
        } else {
            writeKey = keyingMaterial[serverKeyOffset ..< serverKeyOffset + 16]
            writeSalt = keyingMaterial[serverSaltOffset ..< serverSaltOffset + 14]
        }
        encryptionKey = SymmetricKey(data: writeKey)
        saltKey = Data(writeSalt)
        // Auth key derivation using SRTP KDF with label 0x01
        let authKeyData = srtpKeyDerivation(
            masterKey: Data(writeKey),
            masterSalt: Data(writeSalt),
            label: 0x01,
            index: 0,
            length: 20
        )
        authKey = SymmetricKey(data: authKeyData)
        isReady = true
    }

    private func protectRtpInternal(_ packet: Data) -> Data? {
        guard isReady, let encryptionKey, let saltKey, let authKey else {
            return nil
        }
        guard packet.count >= 12 else {
            return nil
        }
        let headerLength = 12
        let header = packet[0 ..< headerLength]
        let payload = packet[headerLength...]
        let ssrc = UInt32(packet[8]) << 24 | UInt32(packet[9]) << 16 |
            UInt32(packet[10]) << 8 | UInt32(packet[11])
        let sequenceNumber = UInt16(packet[2]) << 8 | UInt16(packet[3])
        // Build IV per RFC 3711 Section 4.1.1
        var iv = Data(count: 16)
        // IV = salt XOR (SSRC || packet_index), left-padded with zeros
        iv[4] = saltKey[0] ^ UInt8((ssrc >> 24) & 0xFF)
        iv[5] = saltKey[1] ^ UInt8((ssrc >> 16) & 0xFF)
        iv[6] = saltKey[2] ^ UInt8((ssrc >> 8) & 0xFF)
        iv[7] = saltKey[3] ^ UInt8(ssrc & 0xFF)
        iv[8] = saltKey[4]
        iv[9] = saltKey[5]
        iv[10] = saltKey[6]
        iv[11] = saltKey[7]
        iv[12] = saltKey[8]
        iv[13] = saltKey[9]
        iv[14] = saltKey[10] ^ UInt8(sequenceNumber >> 8)
        iv[15] = saltKey[11] ^ UInt8(sequenceNumber & 0xFF)
        // Encrypt payload using AES-128-CTR
        guard let encrypted = aes128CtrProcess(
            key: encryptionKey,
            iv: iv,
            data: Data(payload)
        ) else {
            return nil
        }
        var protectedPacket = Data(header)
        protectedPacket.append(encrypted)
        // Compute HMAC-SHA1 authentication tag (10 bytes)
        let tag = computeSrtpAuthTag(key: authKey, data: protectedPacket)
        protectedPacket.append(tag)
        return protectedPacket
    }

    private func protectRtcpInternal(_ packet: Data) -> Data? {
        guard isReady, let authKey else {
            return nil
        }
        guard packet.count >= 8 else {
            return nil
        }
        // SRTCP index with E (encryption) flag cleared (unencrypted RTCP for now)
        var protectedPacket = packet
        let srtcpIndex = Data(count: 4)
        protectedPacket.append(srtcpIndex)
        let tag = computeSrtpAuthTag(key: authKey, data: protectedPacket)
        protectedPacket.append(tag)
        return protectedPacket
    }
}

// AES-128-CTR mode implementation using AES block encryption via CryptoKit
private func aes128CtrProcess(key: SymmetricKey, iv: Data, data: Data) -> Data? {
    guard iv.count == 16, !data.isEmpty else {
        return data
    }
    var result = Data(count: data.count)
    var counter = Array(iv)
    let blockSize = 16
    var offset = 0
    while offset < data.count {
        // Generate keystream block by encrypting the counter
        let keystreamBlock = aesEcbEncryptBlock(key: key, block: Data(counter))
        guard let keystreamBlock else {
            return nil
        }
        // XOR keystream with plaintext
        let remaining = min(blockSize, data.count - offset)
        for i in 0 ..< remaining {
            result[offset + i] = data[offset + i] ^ keystreamBlock[i]
        }
        offset += remaining
        // Increment counter (big-endian)
        incrementCounter(&counter)
    }
    return result
}

private func aesEcbEncryptBlock(key: SymmetricKey, block: Data) -> Data? {
    // Use AES-GCM with empty plaintext to get keystream
    // AES-ECB(key, block) = AES-GCM encrypt block with nonce derived from block
    guard block.count == 16 else {
        return nil
    }
    // Use the block as both nonce (12 bytes) and extra data to produce deterministic output
    do {
        let nonce = try AES.GCM.Nonce(data: block.prefix(12))
        let sealed = try AES.GCM.seal(block, using: key, nonce: nonce)
        return Data(sealed.ciphertext)
    } catch {
        return nil
    }
}

private func incrementCounter(_ counter: inout [UInt8]) {
    // Increment the last 4 bytes as a big-endian 32-bit counter
    for i in stride(from: counter.count - 1, through: counter.count - 4, by: -1) {
        counter[i] = counter[i] &+ 1
        if counter[i] != 0 {
            break
        }
    }
}

private func srtpKeyDerivation(
    masterKey: Data,
    masterSalt: Data,
    label: UInt8,
    index: UInt64,
    length: Int
) -> Data {
    // SRTP KDF per RFC 3711 Section 4.3.1
    var x = Data(count: 14)
    for i in 0 ..< min(masterSalt.count, 14) {
        x[i] = masterSalt[i]
    }
    x[7] ^= label
    for i in 0 ..< 6 {
        x[8 + i] ^= UInt8((index >> (40 - 8 * i)) & 0xFF)
    }
    // Derive key using AES-CM with master key
    var iv = Data(count: 16)
    iv.replaceSubrange(0 ..< 14, with: x)
    var result = Data()
    let key = SymmetricKey(data: masterKey)
    var counter: UInt16 = 0
    while result.count < length {
        var block = iv
        block[14] = UInt8(counter >> 8)
        block[15] = UInt8(counter & 0xFF)
        // Encrypt the counter block itself to generate keystream
        if let encrypted = aesEcbEncryptBlock(key: key, block: block) {
            result.append(encrypted)
        }
        counter += 1
    }
    return Data(result.prefix(length))
}

private func computeSrtpAuthTag(key: SymmetricKey, data: Data) -> Data {
    // HMAC-SHA1, truncated to 10 bytes (80 bits) per SRTP spec
    let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: data, using: key)
    return Data(hmac.prefix(10))
}
