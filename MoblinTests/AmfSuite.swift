import AVFoundation
@testable import Moblin
import Testing

struct AmfSuite {
    @Test
    func number() async throws {
        let value = 1.0
        let serializer = Amf0Encoder()
        serializer.encode(value)
        let encoded = serializer.data
        #expect(encoded == Data([0x00, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
        let decoder = Amf0Decoder(data: encoded)
        let decoded = try decoder.decode()
        #expect(decoded as! Double == value)
    }

    struct BoolParameters {
        let value: Bool
        let encoded: Data
    }

    @Test(arguments: [
        BoolParameters(value: true, encoded: Data([1, 1])),
        BoolParameters(value: false, encoded: Data([1, 0])),
    ])
    func bool(_ parameters: BoolParameters) async throws {
        let serializer = Amf0Encoder()
        serializer.encode(parameters.value)
        let encoded = serializer.data
        #expect(encoded == parameters.encoded)
        let decoder = Amf0Decoder(data: encoded)
        let decoded = try decoder.decode()
        #expect(decoded as! Bool == parameters.value)
    }

    @Test
    func string() async throws {
        let value = "1234"
        let serializer = Amf0Encoder()
        serializer.encode(value)
        let encoded = serializer.data
        #expect(encoded == Data([0x02, 0x00, 0x04, 0x31, 0x32, 0x33, 0x34]))
        let decoder = Amf0Decoder(data: encoded)
        let decoded = try decoder.decode()
        #expect(decoded as! String == value)
    }

    @Test
    func object() async throws {
        let value = ["1": "2"]
        let serializer = Amf0Encoder()
        serializer.encode(value)
        let encoded = serializer.data
        #expect(encoded == Data([0x03, 0x00, 0x01, 0x31, 0x02, 0x00, 0x01, 0x32, 0x00, 0x00, 0x09]))
        let decoder = Amf0Decoder(data: encoded)
        let decoded = try decoder.decode()
        #expect(decoded as! [String: String] == value)
    }

    @Test
    func null() async throws {
        let serializer = Amf0Encoder()
        serializer.encode(nil)
        let encoded = serializer.data
        #expect(encoded == Data([0x05]))
        let decoder = Amf0Decoder(data: encoded)
        let decoded = try decoder.decode()
        #expect(decoded as! Bool? == nil)
    }

    @Test
    func undefined() async throws {
        let encoded = Data([0x06])
        let decoder = Amf0Decoder(data: encoded)
        let decoded = try decoder.decode()
        #expect((decoded as! AsUndefined).description == kASUndefined.description)
    }

    @Test
    func ecmaArray() async throws {
        let encoded = Data([
            0x08,
            // 2 elements.
            0x00, 0x00, 0x00, 0x02,
            // Element key "foo".
            0x00, 0x03, 0x66, 0x6F, 0x6F,
            // Element value true.
            0x01, 0x01,
            // Element key "bar".
            0x00, 0x03, 0x62, 0x61, 0x72,
            // Element value "fie".
            0x02, 0x00, 0x03, 0x66, 0x69, 0x65,
            // Empty end key.
            0x00, 0x00,
            // End marker.
            0x09,
        ])
        let decoder = Amf0Decoder(data: encoded)
        let decoded = try decoder.decode() as! AsArray
        #expect(try decoded.get(key: "foo") as! Bool == true)
        #expect(try decoded.get(key: "bar") as! String == "fie")
    }

    @Test
    func strictArray() async throws {
        let encoded = Data([
            0x0A,
            // 2 elements.
            0x00, 0x00, 0x00, 0x02,
            // Element true.
            0x01, 0x01,
            // Element "fie".
            0x02, 0x00, 0x03, 0x66, 0x69, 0x65,
        ])
        let decoder = Amf0Decoder(data: encoded)
        let decoded = try decoder.decode() as! [Any?]
        #expect(try decoded[0] as! Bool == true)
        #expect(try decoded[1] as! String == "fie")
    }

    @Test
    func date() async throws {
        let value = Date(timeIntervalSince1970: 15)
        let serializer = Amf0Encoder()
        serializer.encode(value)
        let encoded = serializer.data
        #expect(encoded == Data([0x0B, 0x40, 0xCD, 0x4C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
        let decoder = Amf0Decoder(data: encoded)
        let decoded = try decoder.decode()
        #expect(decoded as! Date == value)
    }
}
