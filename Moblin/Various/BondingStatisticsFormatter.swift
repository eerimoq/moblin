import SwiftUI

struct BondingConnection {
    let name: String
    var usage: UInt64
}

struct BondingPercentage: Identifiable {
    let id: Int
    let percentage: UInt64
    let color: Color
}

private let colors: [Color] = [
    RgbColor(red: 0xE6, green: 0x9F, blue: 0x00).color(), // Orange
    RgbColor(red: 0x00, green: 0x9E, blue: 0x73).color(), // Green
    RgbColor(red: 0xF0, green: 0xE4, blue: 0x42).color(), // Yellow
    RgbColor(red: 0x00, green: 0x72, blue: 0xB2).color(), // Dark blue
    RgbColor(red: 0xCC, green: 0x79, blue: 0xA7).color(), // Pink
    RgbColor(red: 0x56, green: 0xB4, blue: 0xE9).color(), // Light blue
    RgbColor(red: 0xD5, green: 0x5E, blue: 0x00).color(), // Red
]

class BondingStatisticsFormatter {
    var networkInterfaceNames: [SettingsNetworkInterfaceName] = []

    func setNetworkInterfaceNames(_ networkInterfaceNames: [SettingsNetworkInterfaceName]) {
        self.networkInterfaceNames = networkInterfaceNames
    }

    func format(_ connections: [BondingConnection]) -> (String, [BondingPercentage])? {
        guard !connections.isEmpty else {
            return nil
        }
        var totalUsage = connections.reduce(0) { partialResult, connection in
            partialResult + connection.usage
        }
        if totalUsage == 0 {
            totalUsage = 1
        }
        var percentges = connections.map { connection in
            BondingConnection(name: connection.name, usage: 100 * connection.usage / totalUsage)
        }
        percentges[percentges.count - 1].usage = 100 - percentges
            .prefix(upTo: percentges.count - 1)
            .reduce(0) { total, percentage in
                total + percentage.usage
            }
        let message = percentges.map { percentage in
            "\(percentage.usage)% \(percentage.name)"
        }.joined(separator: ", ")
        return (
            message,
            percentges.enumerated()
                .map { .init(id: $0, percentage: $1.usage, color: getNameColor($1.name)) }
        )
    }

    private func getNameColor(_ name: String) -> Color {
        if name == "Cellular" {
            return colors[0]
        } else if name == "WiFi" {
            return colors[1]
        } else if let index = networkInterfaceNames.firstIndex(where: { name == $0.name }) {
            return colors[(index + 2) % colors.count]
        } else {
            return colors[(2 + networkInterfaceNames.count) % colors.count]
        }
    }
}
