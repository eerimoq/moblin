import Foundation
import Testing

import libsrt
@testable import SRTHaishinKit

@Suite actor SRTSocketOptionTests {
    @Test func parseUri() async {
        guard
            let url = SRTSocketURL(URL(string: "srt://localhost:9000?passphrase=1234&streamid=5678&latency=1935&sndsyn=1&transtype=file")) else {
            return
        }
        let options = url.options
        #expect(options.first { $0.name == .passphrase }?.stringValue == "1234")
        #expect(options.first { $0.name == .streamid }?.stringValue == "5678")
        #expect(options.first { $0.name == .latency }?.intValue == 1935)
        #expect(options.first { $0.name == .sndsyn }?.boolValue == true)
        #expect(options.first { $0.name == .transtype }?.stringValue == SRTT_FILE.rawValue.description)
    }

    @Test func string() throws {
        let socket = srt_create_socket()
        let expect = try SRTSocketOption(name: .streamid, value: "hello")
        try? expect.setSockflag(socket)
        #expect(try SRTSocketOption(name: .streamid, socket: socket).stringValue == "hello")
        srt_close(socket)
    }

    @Test func int32() throws {
        let socket = srt_create_socket()
        let expect = try SRTSocketOption(name: .latency, value: "100")
        try? expect.setSockflag(socket)
        #expect(try SRTSocketOption(name: .latency, socket: socket).intValue == 100)
        srt_close(socket)
    }

    @Test func int64() throws {
        let socket = srt_create_socket()
        let expect = try SRTSocketOption(name: .inputbw, value: "1000")
        try? expect.setSockflag(socket)
        #expect(try SRTSocketOption(name: .inputbw, socket: socket).intValue == 1000)
        srt_close(socket)
    }

    @Test func bool() throws {
        let socket = srt_create_socket()
        let expect = try SRTSocketOption(name: .tlpktdrop, value: "true")
        try? expect.setSockflag(socket)
        #expect(try SRTSocketOption(name: .tlpktdrop, socket: socket).boolValue == true)
        srt_close(socket)
    }

    @Test func transtype() throws {
        let socket = srt_create_socket()
        // The default is true for Live mode, and false for File mode.
        // It does not support transtype.getOption, so I will test it by observing changes in the surrounding properties.
        #expect(try SRTSocketOption(name: .nakreport, socket: socket).boolValue == true)
        let expect = try SRTSocketOption(name: .transtype, value: "file")
        try? expect.setSockflag(socket)
        #expect(try SRTSocketOption(name: .nakreport, socket: socket).boolValue == false)
        srt_close(socket)
    }

    @Test func connection() async throws {
        let connection = SRTConnection()
        let option = try SRTSocketOption(name: .nakreport, value: "no")
        try await connection.setSocketOption(option)
        let result = try await connection.getSocketOption(.nakreport)
        #expect(result?.boolValue == false)
    }

    @Test func rendezvous() throws {
        guard
            let url = SRTSocketURL(URL(string: "srt://:9000?adapter=0.0.0.0")) else {
            return
        }
        #expect(url.local != nil)
        #expect(url.mode == SRTMode.rendezvous)
    }

    @Test func mode() throws {
        #expect(SRTSocketURL(URL(string: "srt://192.168.1.1:9000?mode=caller"))?.mode == SRTMode.caller)
        #expect(SRTSocketURL(URL(string: "srt://192.168.1.1:9000?mode=client"))?.mode == SRTMode.caller)
        #expect(SRTSocketURL(URL(string: "srt://192.168.1.1:9000?mode=listener"))?.mode == SRTMode.listener)
        #expect(SRTSocketURL(URL(string: "srt://192.168.1.1:9000?mode=server"))?.mode == SRTMode.listener)
        #expect(SRTSocketURL(URL(string: "srt://192.168.1.1:9000"))?.mode == SRTMode.caller)
        #expect(SRTSocketURL(URL(string: "srt://:9000"))?.mode == SRTMode.listener)
    }
}
