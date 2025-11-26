import Foundation

class SettingsPrivacyRegion: Codable, Identifiable {
    var id: UUID = .init()
    var latitude: Double = 0
    var longitude: Double = 0
    var latitudeDelta: Double = 30
    var longitudeDelta: Double = 30
}

private func formatMeters(value: Int) -> String {
    if value == 1 {
        return String(localized: "\(value) meter")
    } else {
        return String(localized: "\(value) meters")
    }
}

enum SettingsLocationDesiredAccuracy: Codable, CaseIterable {
    case best
    case nearestTenMeters
    case hundredMeters

    func toString() -> String {
        switch self {
        case .best:
            return String(localized: "Best")
        case .nearestTenMeters:
            return formatMeters(value: 10)
        case .hundredMeters:
            return formatMeters(value: 100)
        }
    }
}

enum SettingsLocationDistanceFilter: Codable, CaseIterable {
    case none
    case oneMeter
    case threeMeters
    case fiveMeters
    case tenMeters
    case twentyMeters
    case fiftyMeters
    case hundredMeters
    case twoHundredMeters

    func toString() -> String {
        switch self {
        case .none:
            return String(localized: "None")
        case .oneMeter:
            return formatMeters(value: 1)
        case .threeMeters:
            return formatMeters(value: 3)
        case .fiveMeters:
            return formatMeters(value: 5)
        case .tenMeters:
            return formatMeters(value: 10)
        case .twentyMeters:
            return formatMeters(value: 20)
        case .fiftyMeters:
            return formatMeters(value: 50)
        case .hundredMeters:
            return formatMeters(value: 100)
        case .twoHundredMeters:
            return formatMeters(value: 200)
        }
    }
}

class SettingsLocation: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var privacyRegions: [SettingsPrivacyRegion] = []
    @Published var distance: Double = 0.0
    @Published var resetWhenGoingLive: Bool = false
    @Published var desiredAccuracy: SettingsLocationDesiredAccuracy = .best
    @Published var distanceFilter: SettingsLocationDistanceFilter = .none

    enum CodingKeys: CodingKey {
        case enabled,
             privacyRegions,
             distance,
             resetWhenGoingLive,
             desiredAccuracy,
             distanceFilter
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.privacyRegions, privacyRegions)
        try container.encode(.distance, distance)
        try container.encode(.resetWhenGoingLive, resetWhenGoingLive)
        try container.encode(.desiredAccuracy, desiredAccuracy)
        try container.encode(.distanceFilter, distanceFilter)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        privacyRegions = container.decode(.privacyRegions, [SettingsPrivacyRegion].self, [])
        distance = container.decode(.distance, Double.self, 0.0)
        resetWhenGoingLive = container.decode(.resetWhenGoingLive, Bool.self, false)
        desiredAccuracy = container.decode(.desiredAccuracy, SettingsLocationDesiredAccuracy.self, .best)
        distanceFilter = container.decode(.distanceFilter, SettingsLocationDistanceFilter.self, .none)
    }
}
