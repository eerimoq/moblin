import Foundation

private let djiTechnologyCoLtd = Data([0xAA, 0x08])
private let djiDeviceModelOsmoAction3 = Data([0x12, 0x00])
private let djiDeviceModelOsmoAction4 = Data([0x14, 0x00])
private let djiDeviceModelOsmoAction5Pro = Data([0x15, 0x00])
private let djiDeviceModelOsmoAction6 = Data([0x18, 0x00])
private let djiDeviceModelOsmoPocket3 = Data([0x20, 0x00])

func djiModelFromManufacturerData(data: Data) -> SettingsDjiDeviceModel {
    guard data.count >= 4 else {
        return .unknown
    }
    switch data[2 ... 3] {
    case djiDeviceModelOsmoAction3:
        return .osmoAction3
    case djiDeviceModelOsmoAction4:
        return .osmoAction4
    case djiDeviceModelOsmoPocket3:
        return .osmoPocket3
    case djiDeviceModelOsmoAction5Pro:
        return .osmoAction5Pro
    case djiDeviceModelOsmoAction6:
        return .osmoAction6
    default:
        return .unknown
    }
}

func isDjiDevice(manufacturerData: Data) -> Bool {
    return manufacturerData.prefix(2) == djiTechnologyCoLtd
}
