import Foundation

private let djiTechnologyCoLtd = Data([0xAA, 0x08])
private let xtraLtd = Data([0xAA, 0xF7])

private struct DjiModel {
    let deviceModel: Data
    let productType: Data
    let model: SettingsDjiDeviceModel
}

private let djiModels = [
    DjiModel(deviceModel: Data([0x10, 0x00]), productType: Data([0x8F, 0x00]), model: .osmoAction2),
    DjiModel(deviceModel: Data([0x12, 0x00]), productType: Data([0xE7, 0x00]), model: .osmoAction3),
    DjiModel(deviceModel: Data([0x14, 0x00]), productType: Data([0xCB, 0x00]), model: .osmoAction4),
    DjiModel(deviceModel: Data([0x15, 0x00]), productType: Data([0xEB, 0x00]), model: .osmoAction5Pro),
    DjiModel(deviceModel: Data([0x17, 0x00]), productType: Data([0xE0, 0x00]), model: .osmo360),
    DjiModel(deviceModel: Data([0x18, 0x00]), productType: Data([0xDF, 0x00]), model: .osmoAction6),
    DjiModel(deviceModel: Data([0x20, 0x00]), productType: Data([0x91, 0x00]), model: .osmoPocket3),
    DjiModel(deviceModel: Data([0x21, 0x00]), productType: Data([0xDB, 0x00]), model: .osmoPocket4),
]

func djiModelFromManufacturerData(data: Data) -> SettingsDjiDeviceModel {
    guard data.count >= 4 else {
        return .unknown
    }
    if data.count >= 14, data[7] & 0x04 != 0,
       let djiModel = djiModels.first(where: { $0.productType == data[12 ... 13] })
    {
        return djiModel.model
    }
    return djiModels.first(where: { $0.deviceModel == data[2 ... 3] })?.model ?? .unknown
}

func isDjiDevice(manufacturerData: Data) -> Bool {
    let companyId = manufacturerData.prefix(2)
    return companyId == djiTechnologyCoLtd || companyId == xtraLtd
}
