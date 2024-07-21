import Foundation

private let djiTechnologyCoLtd = Data([0xAA, 0x08])
private let djiDeviceModelOsmoAction3 = Data([0x12, 0x00])
private let djiDeviceModelOsmoAction4 = Data([0x14, 0x00])
private let djiDeviceModelOsmoPocket3 = Data([0x20, 0x00])

enum DjiDeviceModel {
    case osmoAction3
    case osmoAction4
    case osmoPocket3

    static func fromManufacturerData(data: Data) -> DjiDeviceModel? {
        guard data.count >= 4 else {
            return nil
        }
        switch data[2 ... 3] {
        case djiDeviceModelOsmoAction3:
            return .osmoAction3
        case djiDeviceModelOsmoAction4:
            return .osmoAction4
        case djiDeviceModelOsmoPocket3:
            return .osmoPocket3
        default:
            return nil
        }
    }
}

func isDjiDevice(manufacturerData: Data) -> Bool {
    return manufacturerData.prefix(2) == djiTechnologyCoLtd
}
