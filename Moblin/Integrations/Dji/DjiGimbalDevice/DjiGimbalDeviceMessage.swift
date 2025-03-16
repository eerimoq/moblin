import Foundation

class DjiGimbalZoomMessagePayload {
    // periphery:ignore
    let maybeZoom: Int16
    // periphery:ignore
    let orThisZoom: Int16

    init?(data: Data) {
        let reader = ByteArray(data: data)
        do {
            _ = try reader.readBytes(4)
            maybeZoom = try Int16(bitPattern: reader.readUInt16Le())
            _ = try reader.readBytes(3)
            orThisZoom = try Int16(bitPattern: reader.readUInt16Le())
            _ = try reader.readBytes(2)
        } catch {
            return nil
        }
    }
}

class DjiGimbalButtonsMessagePayload {
    let trigger: Bool
    let switchScene: Bool
    let record: Bool

    init?(data: Data) {
        let reader = ByteArray(data: data)
        do {
            _ = try reader.readBytes(4)
            trigger = try reader.readUInt8().isBitSet(index: 4)
            switchScene = try reader.readUInt8().isBitSet(index: 5)
            record = try reader.readUInt8().isBitSet(index: 3)
            _ = try reader.readBytes(1)
        } catch {
            return nil
        }
    }
}
