import Foundation

/**
 Message Digest Algorithm 5
 - seealso: https://ja.wikipedia.org/wiki/MD5
 - seealso: https://www.ietf.org/rfc/rfc1321.txt
 */
enum MD5 {
    static let a: UInt32 = 0x6745_2301
    static let b: UInt32 = 0xEFCD_AB89
    static let c: UInt32 = 0x98BA_DCFE
    static let d: UInt32 = 0x1032_5476

    static let S11: UInt32 = 7
    static let S12: UInt32 = 12
    static let S13: UInt32 = 17
    static let S14: UInt32 = 22
    static let S21: UInt32 = 5
    static let S22: UInt32 = 9
    static let S23: UInt32 = 14
    static let S24: UInt32 = 20
    static let S31: UInt32 = 4
    static let S32: UInt32 = 11
    static let S33: UInt32 = 16
    static let S34: UInt32 = 23
    static let S41: UInt32 = 6
    static let S42: UInt32 = 10
    static let S43: UInt32 = 15
    static let S44: UInt32 = 21

    struct Context {
        var a: UInt32 = MD5.a
        var b: UInt32 = MD5.b
        var c: UInt32 = MD5.c
        var d: UInt32 = MD5.d

        mutating func FF(_ x: UInt32, _ s: UInt32, _ k: UInt32) {
            let swap: UInt32 = d
            let F: UInt32 = (b & c) | ((~b) & d)
            d = c
            c = b
            b = b &+ rotateLeft(a &+ F &+ k &+ x, s)
            a = swap
        }

        mutating func GG(_ x: UInt32, _ s: UInt32, _ k: UInt32) {
            let swap: UInt32 = d
            let G: UInt32 = (d & b) | (c & ~d)
            d = c
            c = b
            b = b &+ rotateLeft(a &+ G &+ k &+ x, s)
            a = swap
        }

        mutating func HH(_ x: UInt32, _ s: UInt32, _ k: UInt32) {
            let swap: UInt32 = d
            let H: UInt32 = b ^ c ^ d
            d = c
            c = b
            b = b &+ rotateLeft(a &+ H &+ k &+ x, s)
            a = swap
        }

        mutating func II(_ x: UInt32, _ s: UInt32, _ k: UInt32) {
            let swap: UInt32 = d
            let I: UInt32 = c ^ (b | ~d)
            d = c
            c = b
            b = b &+ rotateLeft(a &+ I &+ k &+ x, s)
            a = swap
        }

        func rotateLeft(_ x: UInt32, _ n: UInt32) -> UInt32 {
            ((x << n) & 0xFFFF_FFFF) | (x >> (32 - n))
        }

        var data: Data {
            a.data + b.data + c.data + d.data
        }
    }

    static func base64(_ message: String) -> String {
        calculate(message).base64EncodedString(options: .lineLength64Characters)
    }

    static func calculate(_ message: String) -> Data {
        calculate(ByteArray().writeUTF8Bytes(message).data)
    }

    static func calculate(_ data: Data) -> Data {
        var context = Context()

        let count: Data = UInt64(data.count * 8).bigEndian.data
        let message = ByteArray(data: data + [0x80])
        message.length += 64 - (message.length % 64)
        message[message.length - 8] = count[7]
        message[message.length - 7] = count[6]
        message[message.length - 6] = count[5]
        message[message.length - 5] = count[4]
        message[message.length - 4] = count[3]
        message[message.length - 3] = count[2]
        message[message.length - 2] = count[1]
        message[message.length - 1] = count[0]

        // swiftlint:disable:this closure_body_length
        message.sequence(64) {
            let x: [UInt32] = $0.toUInt32()

            guard x.count == 16 else {
                return
            }

            var ctx = Context()
            ctx.a = context.a
            ctx.b = context.b
            ctx.c = context.c
            ctx.d = context.d

            /* Round 1 */
            ctx.FF(x[0], S11, 0xD76A_A478)
            ctx.FF(x[1], S12, 0xE8C7_B756)
            ctx.FF(x[2], S13, 0x2420_70DB)
            ctx.FF(x[3], S14, 0xC1BD_CEEE)
            ctx.FF(x[4], S11, 0xF57C_0FAF)
            ctx.FF(x[5], S12, 0x4787_C62A)
            ctx.FF(x[6], S13, 0xA830_4613)
            ctx.FF(x[7], S14, 0xFD46_9501)
            ctx.FF(x[8], S11, 0x6980_98D8)
            ctx.FF(x[9], S12, 0x8B44_F7AF)
            ctx.FF(x[10], S13, 0xFFFF_5BB1)
            ctx.FF(x[11], S14, 0x895C_D7BE)
            ctx.FF(x[12], S11, 0x6B90_1122)
            ctx.FF(x[13], S12, 0xFD98_7193)
            ctx.FF(x[14], S13, 0xA679_438E)
            ctx.FF(x[15], S14, 0x49B4_0821)

            /* Round 2 */
            ctx.GG(x[1], S21, 0xF61E_2562)
            ctx.GG(x[6], S22, 0xC040_B340)
            ctx.GG(x[11], S23, 0x265E_5A51)
            ctx.GG(x[0], S24, 0xE9B6_C7AA)
            ctx.GG(x[5], S21, 0xD62F_105D)
            ctx.GG(x[10], S22, 0x2441453)
            ctx.GG(x[15], S23, 0xD8A1_E681)
            ctx.GG(x[4], S24, 0xE7D3_FBC8)
            ctx.GG(x[9], S21, 0x21E1_CDE6)
            ctx.GG(x[14], S22, 0xC337_07D6)
            ctx.GG(x[3], S23, 0xF4D5_0D87)
            ctx.GG(x[8], S24, 0x455A_14ED)
            ctx.GG(x[13], S21, 0xA9E3_E905)
            ctx.GG(x[2], S22, 0xFCEF_A3F8)
            ctx.GG(x[7], S23, 0x676F_02D9)
            ctx.GG(x[12], S24, 0x8D2A_4C8A)

            /* Round 3 */
            ctx.HH(x[5], S31, 0xFFFA_3942)
            ctx.HH(x[8], S32, 0x8771_F681)
            ctx.HH(x[11], S33, 0x6D9D_6122)
            ctx.HH(x[14], S34, 0xFDE5_380C)
            ctx.HH(x[1], S31, 0xA4BE_EA44)
            ctx.HH(x[4], S32, 0x4BDE_CFA9)
            ctx.HH(x[7], S33, 0xF6BB_4B60)
            ctx.HH(x[10], S34, 0xBEBF_BC70)
            ctx.HH(x[13], S31, 0x289B_7EC6)
            ctx.HH(x[0], S32, 0xEAA1_27FA)
            ctx.HH(x[3], S33, 0xD4EF_3085)
            ctx.HH(x[6], S34, 0x4881D05)
            ctx.HH(x[9], S31, 0xD9D4_D039)
            ctx.HH(x[12], S32, 0xE6DB_99E5)
            ctx.HH(x[15], S33, 0x1FA2_7CF8)
            ctx.HH(x[2], S34, 0xC4AC_5665)

            /* Round 4 */
            ctx.II(x[0], S41, 0xF429_2244)
            ctx.II(x[7], S42, 0x432A_FF97)
            ctx.II(x[14], S43, 0xAB94_23A7)
            ctx.II(x[5], S44, 0xFC93_A039)
            ctx.II(x[12], S41, 0x655B_59C3)
            ctx.II(x[3], S42, 0x8F0C_CC92)
            ctx.II(x[10], S43, 0xFFEF_F47D)
            ctx.II(x[1], S44, 0x8584_5DD1)
            ctx.II(x[8], S41, 0x6FA8_7E4F)
            ctx.II(x[15], S42, 0xFE2C_E6E0)
            ctx.II(x[6], S43, 0xA301_4314)
            ctx.II(x[13], S44, 0x4E08_11A1)
            ctx.II(x[4], S41, 0xF753_7E82)
            ctx.II(x[11], S42, 0xBD3A_F235)
            ctx.II(x[2], S43, 0x2AD7_D2BB)
            ctx.II(x[9], S44, 0xEB86_D391)

            context.a = context.a &+ ctx.a
            context.b = context.b &+ ctx.b
            context.c = context.c &+ ctx.c
            context.d = context.d &+ ctx.d
        }

        return context.data
    }
}
