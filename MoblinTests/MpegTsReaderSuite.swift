import AVFoundation
@testable import Moblin
import Testing

private class Mock: MpegTsReaderDelegate {
    var audioSampleBuffers: [CMSampleBuffer] = []
    var videoSampleBuffers: [CMSampleBuffer] = []

    func mpegTsReaderAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        audioSampleBuffers.append(sampleBuffer)
    }

    func mpegTsReaderVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        videoSampleBuffers.append(sampleBuffer)
    }

    func mpegTsReaderSetTargetLatencies(_: Double, _: Double) {}
}

// swiftlint:disable line_length

struct MpegTsReaderSuite {
    @Test
    func audio() throws {
        let mock = Mock()
        let reader = MpegTsReader(decoderQueue: .main,
                                  timecodesEnabled: false,
                                  targetLatency: 1.0)
        reader.delegate = mock
        var packet =
            try Data(
                hexString: "474011100042f0250001c10000ff01ff0001fc80144812010646466d70656709536572766963653031777c43caffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff474000100000b00d0001c100000001f0002ab104b2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff475000100002b0120001c10000e100f0000fe100f000b69bc0d9ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47410030075000007b0c7e00000001c003c9808005210007d861fff14c4040dffcde02004c61766336322e32382e313032000248ae5f28e83d0b0b4af1e43bebbfae75defa5eb2cd6f55adcce7ae67ccf300ba820244211213b2bb24910844a4244211290914844a4246211314918a44c6fc97e74920c4507fbf7ed494c9446848253e691a72c9398460b4943691870495b9c46d592586a847098225321119f24957a4471348958bd2a6e09f35ea24b41832398d892d2d3234f0a4b0470100119088c7a04a9348c2864a32c8c9844a3c0231964a0348c23926288cd7928f008c76928ac230984a1a08a08492122611238089418f8a454224919148491c44500246063d363e2e3d26044c0477712ed159c3b345670ac50d9c0b1436302a507eeb013e046c04b771701259c5bb496712cd1d9c3f05f62f15f62f15f16f15eaaea9e4aa9415903f0b5903f0bf4efa6fd3be9bf1de83f1dd73d75d73d75c93c95c93c95c93c4b88f12a241f4ef69fa77b4fb57b4fa17a0f737a047010012f73772f73745e8dd17a3745e8dd177ade75ade75ad675ae8bd1ba2f46e5bcbb96f2ee5bad6b3ad6b3ad6b3ad5a6d569b55a6d569b55a6d569b55a6d569b52d5cb572d5cb572d5cb572d5cb575e6f579bd5e6ad55ab556ad55ab556ad55ab4a972a5ca972a5ca972a5ca972a5ca972a5ca972a5ca972a5ca972a5cb2cb2cb2cb2cb2cb2cb2cb2ff97fcbfe5ff2ff97fcbfe5ff2cb3cb3cb3cb3cb3cb3cb3cb3cb3cb3cb3cb3cb3cb3cb3cb3f0fff14c4022dffc01369cdaf4470100135d77f80fc07e1faff6ff3fa7fe7ae166eebcffe37f6ff0eb8d71ad1001715ed6c437772abf8a0d0b654830eed75d8b6de0ebb5b8d8b8d3674d9d3674d9ccb4cb4494495cebf2eee6e80732748a03e0175077b945807f7348bb5bc01a8f3431aa00769e7ed498bbf9d2a4380006f0c574dec4556253540000e87d1dc51b1dc4d2a47c0003be3927d0feb9cf3b29c2e6536c389da0000015807f87c8dcebf2fe893871ba5ccc734000000ad412f06cc15d61f1af7098a6d723"
            )
        try reader.handlePacketFromClient(packet: packet)
        #expect(mock.audioSampleBuffers.count == 0)
        #expect(mock.videoSampleBuffers.count == 0)
        packet =
            try Data(
                hexString: "470100146e0b02000000fedd680eddedbfda777f6575035be62d01606d3b5bc00000001f9fe44e2de5ffb8763edeeb45b70c19bab0e276ce000000003eafd15c93f1ff60e85e76f9471b85dd3954753b5b800000001cfff14c40017ffc0118e007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c470100357800ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007"
            )
        try reader.handlePacketFromClient(packet: packet)
        #expect(mock.audioSampleBuffers.count == 0)
        #expect(mock.videoSampleBuffers.count == 0)
        packet =
            try Data(
                hexString: "474000110000b00d0001c100000001f0002ab104b2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff475000110002b0120001c10000e100f0000fe100f000b69bc0d9ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4741003607500000bacc7e00000001c000c3808005210009d761fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01470100379e00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff182007fff14c40017ffc01182007fff14c40017ffc01182007"
            )
        try reader.handlePacketFromClient(packet: packet)
        #expect(mock.audioSampleBuffers.count == 17)
        #expect(mock.videoSampleBuffers.count == 0)
        packet =
            try Data(
                hexString: "474011110042f0250001c10000ff01ff0001fc80144812010646466d70656709536572766963653031777c43caffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff474000120000b00d0001c100000001f0002ab104b2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff475000120002b0120001c10000e100f0000fe100f000b69bc0d9ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4741003807500000fa8c7e00000001c0048980800521000bd661fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01184007fff14c404efffc01189d343f17f8bfc5fb0508470100191e7895faa7dfff1f63ee49e6debebf4fb1f8fc3f515e3904e54d2742813a16c9e3b316be10860f28430d3884079069c80c78f05facfb276a1028c80438f03fe420729019080c440012030900031e03fc9fc4fc07ae76a7747647166c4211611083088417907388398416b20b490420820c40a620621019080c440212041100888041ffe7fe1facfbe7d4084888420c021018412820726000fb43e3f4b938ff4e9712486522466f19489d678f15e8d936290c1fa808e0424b4701001a8873321d1144f05e2323c4a411723d8683672a6041d1a4654922b3506b95044822fc09162c894444a5c7a1e07a8325d59dc5a47129e48885ff8fffbf7dd06fd359a46505773491003f8bfe5fbecd5e1e5e1a9a5892fffbfadff2fdf7f5bf9d795cbd72f5cc4953254c948ad6452922a5114208a5244e76d2aab2aab2abb9a5a9a5a9a48bde45ad22e7116308b5a456b56555655563ad4d2d4d2d4c2458c22b5915ac8a94456b22a5115288a5278e9e3a7972f5c992a64a994701001b2a643dabdabdabdabdabdabdabdaa59400000031a0000004604022f7917bc8bde45ef22f7917bc8bde59459458838830a30a60007beb7c5fb5c085ba32bb315c7c02393f0013c9c42192d15ddc17ef16dcaa2bcb3a03d6e8927731074226651009727848ca292821c7abbb8df54f87e60dc7628ea607caf83105c62688440ae262591ab0c9508046638948590027279b2a13218ee80dd60231124a0a08bcc49a522b19248bf29edfe31e27cc9bfc89c248c0c7a4c087808a"
            )
        try reader.handlePacketFromClient(packet: packet)
        #expect(mock.audioSampleBuffers.count == 34)
        #expect(mock.videoSampleBuffers.count == 0)
        packet =
            try Data(
                hexString: "4701001cee0ee8d17a230fc32c3b341fd6fbcfdabed3f152248f2244e2113883bf9a79bb66ececd39ab09c2904d04d04c039b3a6b4c94494060606066e595f80fff14c402cbffc01049c6efda57f80fc07e0fb7ddf8aa6fae76ff7aefccfbd8ef5e008e2944f2d68859d311bfa3259fe3581e8885bc49181228ba04233c9e038212bb93a033e4f1d80207b8462c327544425ccb7e39251acc844d4b94177697035101a251354c2fa67c9ee6da3ec7e21688e561e004c1c7f76b505dd4701001d7c333eeefe2cd5f6d670ceed93b6bc460e3ae167d352dcec951a6c612f44fc1a23b6f85c43b9fa409fa43ac91ed560974ee2c47c53e932585f3b93eabe3221e2fe044bf04be6423f3a7e3712f0c7c3327e07f1191f7575d25e47f6513e15eaa21e9ee7e4bdb1d508f97bcd24b39e4c27d478f91f0470f25c97bf93d1f6221dd7164bc1bc748f38ed19d3a393e3f8823cc7724b3fcd09e738810e68025a0c291b39a20cc354f862385b44998a2785c711d89896a736468ea84701003e7000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff856c412ce988e47264879d27014466849468f74c920c39290222e8d2646270444649493a349f1300804a3208aa3e090f80fff14c40017ffc0118e007fff14c40017ffc01182007"
            )
        try reader.handlePacketFromClient(packet: packet)
        #expect(mock.audioSampleBuffers.count == 34)
        #expect(mock.videoSampleBuffers.count == 0)
        packet =
            try Data(
                hexString: "474000130000b00d0001c100000001f0002ab104b2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff475000130002b0120001c10000e100f0000fe100f000b69bc0d9ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4741003f075000013a4c7e00000001c000c380800521000dd561fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01470100309e00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff182007fff14c40017ffc01182007fff14c40017ffc01182007"
            )
        try reader.handlePacketFromClient(packet: packet)
        #expect(mock.audioSampleBuffers.count == 51)
        #expect(mock.videoSampleBuffers.count == 0)
        packet =
            try Data(
                hexString: "474011120042f0250001c10000ff01ff0001fc80144812010646466d70656709536572766963653031777c43caffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff474000140000b00d0001c100000001f0002ab104b2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff475000140002b0120001c10000e100f0000fe100f000b69bc0d9ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47410031075000017a0c7e00000001c000c380800521000fd461fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01470100329e00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff182007fff14c40017ffc01182007fff14c40017ffc01182007"
            )
        try reader.handlePacketFromClient(packet: packet)
        #expect(mock.audioSampleBuffers.count == 68)
        #expect(mock.videoSampleBuffers.count == 0)
        packet =
            try Data(
                hexString: "474000150000b00d0001c100000001f0002ab104b2ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff475000150002b0120001c10000e100f0000fe100f000b69bc0d9ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4741003307500001b9cc7e00000001c003d7808005210011d361fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01182007fff14c40017ffc01184007fff14c40579ffc01189c6c3f17f8bfc5fe00f3c4afd53efff8fb1f724f36f5f5ff61f75fdf7a250272a693a1409d0b64f1d98b5f0843079421869c4203c83447010014e4063c782fd67d93b5081464021c781ff21039480c8406220009018480018f01fe4fe27e03d73b53ba3b238b362108b0884184420bc839c41cc20b5905a48210410620531031080c8406220109020880444020fff3ff0fd67df3ea042444210601080c2094103930007da1f1fa5c9c7fa74b8924329123378ca44eb3c78af46c9b14860fd404702125c439990e88a2782f1191e25208b91ec341b3953020e8d232a49159a835ca8224117e048b1644a22252e3d0f03d419247010015eacee2d23894f24442ffc7ffdfbee837e9acd23282bb9a48801fc5ff2fdf66af0f2f0d4d2c497ffdfd6ff97efbfadfcebcae5eb97ae624a992a64a456b2294915288a1045292273b695559555955dcd2d4d2d4d245ef22d6917388b1845ad22b5ab2aab2aab1d6a696a696a6122c6115ac8ad6454a22b5915288a9445293c74f1d3cb97ae4c953254c95321ed5ed5ed5ed5ed5ed5ed5ed52ca00000018d00000023020117bc8bde45ef22f7917bc8bde45ef2ca2ca2c41c44701001618518530001940dd316a0484ce0dd195d98ae3e01003088564727e002793884325a2bbb8292cff1ac0f45f78b6e5515e44004f39fe8765d021eb2a2e8108cfc427b823bf42d9520c3b3bbf2712843e3f13b18d813c35d4e15ab40bf7d99c7ffe67cb9e6c9bfaa79bb5ae6ac9f6494680429089c692c0c6c0c6811c561ce9753a5aa505dda5c0d44068944d5309818d411a04715753a5d4e96a210024cacad9340a09a84400a408d023403acad2cad2ca6b74b2b1881c195c47010017d7506d42083883883883a54c94f1d3c74f13206dc2ff065b190102b717dca5410838838838839d3c74614614626214f84fdad0642000ca62f96ac0661a61a20e20e516516500065707d6bc36b307f03a57b3aa4070fff14c400ddffc01049cdaf9ac1f80fc07e0f7f8effc73e79d4dd582445d42cc987b3cf9b73567524a43b9ea8253c0460af2127f07b077165bc7159173a83cfb67ebbb161ed1af673b85cf6dd8b0fa4742e26d97bca6dcde1639e5843358236b5b2530"
            )
        try reader.handlePacketFromClient(packet: packet)
        #expect(mock.audioSampleBuffers.count == 85)
        #expect(mock.videoSampleBuffers.count == 0)
        let firstPresentationTimeStamp = try #require(mock.audioSampleBuffers.first?.presentationTimeStamp
            .seconds)
        #expect(areEqual(mock.audioSampleBuffers.map(\.presentationTimeStamp.seconds),
                         [
                             firstPresentationTimeStamp,
                             firstPresentationTimeStamp + 0.02099,
                             firstPresentationTimeStamp + 0.04200,
                             firstPresentationTimeStamp + 0.06399,
                             firstPresentationTimeStamp + 0.08499,
                             firstPresentationTimeStamp + 0.10599,
                             firstPresentationTimeStamp + 0.12799,
                             firstPresentationTimeStamp + 0.14899,
                             firstPresentationTimeStamp + 0.16999,
                             firstPresentationTimeStamp + 0.19199,
                             firstPresentationTimeStamp + 0.21300,
                             firstPresentationTimeStamp + 0.23399,
                             firstPresentationTimeStamp + 0.25599,
                             firstPresentationTimeStamp + 0.27700,
                             firstPresentationTimeStamp + 0.29799,
                             firstPresentationTimeStamp + 0.31999,
                             firstPresentationTimeStamp + 0.34100,
                             firstPresentationTimeStamp + 0.36266,
                             firstPresentationTimeStamp + 0.38366,
                             firstPresentationTimeStamp + 0.40466,
                             firstPresentationTimeStamp + 0.42666,
                             firstPresentationTimeStamp + 0.44766,
                             firstPresentationTimeStamp + 0.46866,
                             firstPresentationTimeStamp + 0.49066,
                             firstPresentationTimeStamp + 0.51166,
                             firstPresentationTimeStamp + 0.53266,
                             firstPresentationTimeStamp + 0.55466,
                             firstPresentationTimeStamp + 0.57566,
                             firstPresentationTimeStamp + 0.59666,
                             firstPresentationTimeStamp + 0.61866,
                             firstPresentationTimeStamp + 0.63966,
                             firstPresentationTimeStamp + 0.66066,
                             firstPresentationTimeStamp + 0.68266,
                             firstPresentationTimeStamp + 0.70366,
                             firstPresentationTimeStamp + 0.72533,
                             firstPresentationTimeStamp + 0.74633,
                             firstPresentationTimeStamp + 0.76733,
                             firstPresentationTimeStamp + 0.78933,
                             firstPresentationTimeStamp + 0.81033,
                             firstPresentationTimeStamp + 0.83133,
                             firstPresentationTimeStamp + 0.85333,
                             firstPresentationTimeStamp + 0.87433,
                             firstPresentationTimeStamp + 0.89533,
                             firstPresentationTimeStamp + 0.91733,
                             firstPresentationTimeStamp + 0.93833,
                             firstPresentationTimeStamp + 0.95933,
                             firstPresentationTimeStamp + 0.98133,
                             firstPresentationTimeStamp + 1.00233,
                             firstPresentationTimeStamp + 1.02333,
                             firstPresentationTimeStamp + 1.04533,
                             firstPresentationTimeStamp + 1.06633,
                             firstPresentationTimeStamp + 1.08800,
                             firstPresentationTimeStamp + 1.10899,
                             firstPresentationTimeStamp + 1.12999,
                             firstPresentationTimeStamp + 1.15200,
                             firstPresentationTimeStamp + 1.17299,
                             firstPresentationTimeStamp + 1.19400,
                             firstPresentationTimeStamp + 1.21600,
                             firstPresentationTimeStamp + 1.23699,
                             firstPresentationTimeStamp + 1.25800,
                             firstPresentationTimeStamp + 1.27999,
                             firstPresentationTimeStamp + 1.30099,
                             firstPresentationTimeStamp + 1.32200,
                             firstPresentationTimeStamp + 1.34399,
                             firstPresentationTimeStamp + 1.36499,
                             firstPresentationTimeStamp + 1.38599,
                             firstPresentationTimeStamp + 1.40799,
                             firstPresentationTimeStamp + 1.42899,
                             firstPresentationTimeStamp + 1.45066,
                             firstPresentationTimeStamp + 1.47166,
                             firstPresentationTimeStamp + 1.49266,
                             firstPresentationTimeStamp + 1.51466,
                             firstPresentationTimeStamp + 1.53566,
                             firstPresentationTimeStamp + 1.55666,
                             firstPresentationTimeStamp + 1.57866,
                             firstPresentationTimeStamp + 1.59966,
                             firstPresentationTimeStamp + 1.62066,
                             firstPresentationTimeStamp + 1.64266,
                             firstPresentationTimeStamp + 1.66366,
                             firstPresentationTimeStamp + 1.68466,
                             firstPresentationTimeStamp + 1.70666,
                             firstPresentationTimeStamp + 1.72766,
                             firstPresentationTimeStamp + 1.74866,
                             firstPresentationTimeStamp + 1.77066,
                             firstPresentationTimeStamp + 1.79166,
                         ],
                         epsilon: 0.001))
        for audioSampleBuffer in mock.audioSampleBuffers {
            #expect(audioSampleBuffer.totalSampleSize == 1024 * 2)
        }
    }
}

// swiftlint:enable line_length
