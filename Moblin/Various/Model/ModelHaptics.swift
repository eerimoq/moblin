import Foundation

extension Model: HapticsDelegate {
    func hapticsActiveChanged() {
        setAllowHapticsAndSystemSoundsDuringRecording()
    }
}
