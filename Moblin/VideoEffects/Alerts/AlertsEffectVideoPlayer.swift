import AVFoundation

func playAudio(sampleBuffers: [CMSampleBuffer]) throws {
    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    engine.attach(playerNode)
    engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
    try engine.start()
    for sampleBuffer in sampleBuffers {
        // if let pcmBuffer = sampleBuffer {
        //     playerNode.scheduleBuffer(pcmBuffer, completionHandler: nil)
        // }
    }
    playerNode.play()
}
