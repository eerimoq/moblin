import Foundation

struct DjiGimbalZoomMessagePayload {
    // periphery:ignore
    let maybeZoom: Int16
    // periphery:ignore
    let orThisZoom: Int16

    init?(data: Data) {
        // Three in a row with 0 zoom makes it a button press?
        let reader = ByteArray(data: data)
        do {
            _ = try reader.readBytes(4)
            maybeZoom = try Int16(bitPattern: reader.readUInt16Le())
            _ = try reader.readBytes(3)
            orThisZoom = try Int16(bitPattern: reader.readUInt16Le())
        } catch {
            return nil
        }
    }
}

enum DjiGimbalTriggerButtonPress: UInt8 {
    case single = 1
    case double = 2
    case triple = 3
    case long = 7
}

struct DjiGimbalButtonsMessagePayload {
    let trigger: DjiGimbalTriggerButtonPress?
    let switchScene: Bool
    let record: Bool

    init?(data: Data) {
        let reader = ByteArray(data: data)
        do {
            _ = try reader.readBytes(4)
            trigger = try DjiGimbalTriggerButtonPress(rawValue: reader.readUInt8() >> 4 & 0x7)
            switchScene = try reader.readUInt8().isBitSet(index: 5)
            record = try reader.readUInt8().isBitSet(index: 3)
            _ = try reader.readBytes(1)
        } catch {
            return nil
        }
    }
}
