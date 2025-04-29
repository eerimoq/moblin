import Foundation

private let djiDeviceModelOsmoMobile7p = Data([0x64, 0x00])

func djiGimbalModelFromManufacturerData(data: Data) -> SettingsDjiGimbalDeviceModel {
    guard data.count >= 4 else {
        return .unknown
    }
    switch data[2 ... 3] {
    case djiDeviceModelOsmoMobile7p:
        return .osmoMobile7P
    default:
        return .unknown
    }
}
