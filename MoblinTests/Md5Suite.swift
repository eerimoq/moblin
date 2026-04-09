@testable import Moblin
import SwiftUI
import Testing

struct Md5Suite {
    @Test
    func appleLogToRec709() throws {
        var expected = try Data(hexString: "d41d8cd98f00b204e9800998ecf8427e")
        #expect(MD5.calculate("") == expected)
        expected = try Data(hexString: "0cc175b9c0f1b6a831c399e269772661")
        #expect(MD5.calculate("a") == expected)
        expected = try Data(hexString: "900150983cd24fb0d6963f7d28e17f72")
        #expect(MD5.calculate("abc") == expected)
        expected = try Data(hexString: "f96b697d7cb7938d525a2f31aaf161d0")
        #expect(MD5.calculate("message digest") == expected)
        expected = try Data(hexString: "c3fcd3d76192e4007dfb496cca67e13b")
        #expect(MD5.calculate("abcdefghijklmnopqrstuvwxyz") == expected)
        expected = try Data(hexString: "b76972fe0dff4baac395b531646f738e")
        #expect(MD5.calculate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz012") == expected)
        expected = try Data(hexString: "27eca74a76daae63f472b250b5bcff9d")
        #expect(MD5.calculate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123") == expected)
        expected = try Data(hexString: "d174ab98d277d9f5a5611c2c9f419d9f")
        #expect(MD5.calculate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") == expected)
        expected = try Data(hexString: "844581cc08fda9c8eb0b449acb7c322b")
        #expect(MD5.calculate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789a") == expected)
        expected = try Data(hexString: "a27155ae242d64584221b66416d22a61")
        #expect(MD5.calculate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ab") == expected)
        expected = try Data(hexString: "57edf4a22be3c955ac49da2e2107b67a")
        #expect(MD5
            .calculate("12345678901234567890123456789012345678901234567890123456789012345678901234567890") ==
            expected)
    }
}
