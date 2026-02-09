import AVFoundation
import Foundation
import Testing

@testable import RTCHaishinKit

@Suite struct RTPFormatParamterTests {
    @Test func opus() throws {
        let parameter = RTPFormatParameter("minptime=10;useinbandfec=1;stereo=1")
        #expect(parameter.stereo == true)
        #expect(parameter.minptime == 10)
    }
}
