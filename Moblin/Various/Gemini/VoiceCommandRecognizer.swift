import AVFoundation
import CoreAudio
import Foundation
import Speech

class VoiceCommandRecognizer: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private(set) var isRecording = false
    private var lastTranscribedText = ""

    func startRecording(
        onTextUpdated: @escaping (String) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        stopRecording()
        lastTranscribedText = ""

        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                guard authStatus == .authorized else {
                    completion(.failure(NSError(
                        domain: "VoiceCommandRecognizer",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "Permissão de reconhecimento de voz negada"]
                    )))
                    return
                }

                self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                guard let recognitionRequest = self.recognitionRequest else {
                    completion(.failure(NSError(
                        domain: "VoiceCommandRecognizer",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Falha ao criar request"]
                    )))
                    return
                }

                recognitionRequest.shouldReportPartialResults = true
                self.isRecording = true

                self.recognitionTask = self.speechRecognizer?
                    .recognitionTask(with: recognitionRequest) { [weak self] result, error in
                        guard let self else { return }

                        if let result {
                            let text = result.bestTranscription.formattedString
                            lastTranscribedText = text
                            onTextUpdated(text)

                            if result.isFinal {
                                isRecording = false
                                completion(.success(text))
                            }
                        }

                        if let error {
                            isRecording = false
                            let nsError = error as NSError
                            // Code 301 or 4 are typically normal stop/cancel errors
                            if nsError.code != 301, nsError.code != 4 {
                                completion(.failure(error))
                            } else {
                                completion(.success(lastTranscribedText))
                            }
                        }
                    }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionRequest = nil
        recognitionTask = nil
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording, let recognitionRequest else { return }

        guard let formatDescription = sampleBuffer.formatDescription,
              var asbd = formatDescription.audioStreamBasicDescription
        else {
            return
        }
        guard let format = AVAudioFormat(streamDescription: &asbd) else {
            return
        }
        let frameCount = AVAudioFrameCount(sampleBuffer.numSamples)
        guard frameCount > 0,
              let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else {
            return
        }
        pcmBuffer.frameLength = frameCount
        do {
            try sampleBuffer.withAudioBufferList { srcList, _ in
                let dstList = UnsafeMutableAudioBufferListPointer(pcmBuffer.mutableAudioBufferList)
                for i in 0 ..< min(srcList.count, dstList.count) {
                    guard let src = srcList[i].mData, let dst = dstList[i].mData else {
                        continue
                    }
                    let byteCount = Int(min(srcList[i].mDataByteSize, dstList[i].mDataByteSize))
                    dst.copyMemory(from: src, byteCount: byteCount)
                }
            }
            recognitionRequest.append(pcmBuffer)
        } catch {
            return
        }
    }
}
