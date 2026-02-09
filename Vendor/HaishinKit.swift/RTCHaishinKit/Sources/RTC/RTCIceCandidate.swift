import Foundation

public struct RTCIceCandidate: Sendable {
    public let candidate: String
    public let mid: String
}

extension RTCIceCandidate {
    init(candidate: UnsafePointer<CChar>?, mid: UnsafePointer<CChar>?) {
        if let candidate {
            self.candidate = String(cString: candidate)
        } else {
            self.candidate = ""
        }
        if let mid {
            self.mid = String(cString: mid)
        } else {
            self.mid = ""
        }
    }
}
