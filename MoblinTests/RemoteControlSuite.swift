import Foundation
@testable import Moblin
import Testing

struct RemoteControlSuite {
    @Test
    func remoteSceneDataTextStats() throws {
        let textStats = RemoteControlRemoteSceneDataTextStats(stats: createStats())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let encoded = try String(bytes: encoder.encode(textStats), encoding: .utf8)
        #expect(encoded == """
        {
          "activeEnergyBurned" : 350,
          "altitude" : 243.5,
          "altitudeAscent" : 120.25,
          "altitudeDescent" : 80.5,
          "area" : "Malmö",
          "averageSpeed" : 7.25,
          "bitrate" : "5000 kbps",
          "bitrateAndTotal" : "5000 kbps, 1.2 GB",
          "browserTitle" : "Title",
          "city" : "Malmö",
          "conditions" : "sun.max",
          "country" : "Sweden",
          "countryFlag" : "🇸🇪",
          "cyclingCadence" : "90",
          "cyclingPower" : "250 W",
          "date" : 745043166,
          "debugOverlayLines" : [
            "First line",
            "Second line"
          ],
          "distance" : 1700.75,
          "feelsLikeTemperature" : {
            "unit" : {
              "converter" : {
                "coefficient" : 1,
                "constant" : 273.15
              },
              "symbol" : "°C"
            },
            "value" : 17
          },
          "fps" : 30,
          "gForce" : {
            "max" : 3.5,
            "now" : 1.5,
            "recentMax" : 2.5
          },
          "heartRates" : {
            "Belt" : null,
            "Watch" : 75
          },
          "latestFollower" : "Follower",
          "latestSubscriber" : "Subscriber",
          "muted" : true,
          "neighborhood" : "Möllevången",
          "power" : 210,
          "resolution" : "1920x1080",
          "runningMetrics" : {
            "Foot pod" : {
              "cadence" : 180,
              "distance" : 4200,
              "speed" : 3.5
            }
          },
          "slope" : "5%",
          "speed" : 5.5,
          "splitAltitudeAscent" : 40.75,
          "splitAltitudeDescent" : 30.25,
          "splitDistance" : 5400.5,
          "state" : "Skåne",
          "stepCount" : 8000,
          "temperature" : {
            "unit" : {
              "converter" : {
                "coefficient" : 1,
                "constant" : 273.15
              },
              "symbol" : "°C"
            },
            "value" : 22
          },
          "teslaBatteryLevel" : "80%",
          "teslaDrive" : "D",
          "teslaMedia" : "Song",
          "windGust" : {
            "unit" : {
              "converter" : {
                "coefficient" : 1,
                "constant" : 0
              },
              "symbol" : "m\\/s"
            },
            "value" : 8.5
          },
          "windSpeed" : {
            "unit" : {
              "converter" : {
                "coefficient" : 1,
                "constant" : 0
              },
              "symbol" : "m\\/s"
            },
            "value" : 3
          },
          "workoutDistance" : 4200
        }
        """)
    }

    private func createStats() -> TextEffectStats {
        TextEffectStats(timestamp: .now,
                        bitrate: "5000 kbps",
                        bitrateAndTotal: "5000 kbps, 1.2 GB",
                        resolution: "1920x1080",
                        fps: 30,
                        date: Date(timeIntervalSince1970: 1_723_350_366),
                        debugOverlayLines: ["First line", "Second line"],
                        speed: 5.5,
                        averageSpeed: 7.25,
                        altitude: 243.5,
                        distance: 1700.75,
                        splitDistance: 5400.5,
                        altitudeAscent: 120.25,
                        altitudeDescent: 80.5,
                        splitAltitudeAscent: 40.75,
                        splitAltitudeDescent: 30.25,
                        slope: "5%",
                        conditions: "sun.max",
                        temperature: Measurement(value: 22, unit: UnitTemperature.celsius),
                        feelsLikeTemperature: Measurement(value: 17, unit: UnitTemperature.celsius),
                        windSpeed: Measurement(value: 3, unit: UnitSpeed.metersPerSecond),
                        windGust: Measurement(value: 8.5, unit: UnitSpeed.metersPerSecond),
                        country: "Sweden",
                        countryFlag: "🇸🇪",
                        state: "Skåne",
                        area: "Malmö",
                        city: "Malmö",
                        neighborhood: "Möllevången",
                        muted: true,
                        heartRates: ["Watch": 75, "Belt": nil],
                        activeEnergyBurned: 350,
                        workoutDistance: 4200,
                        power: 210,
                        stepCount: 8000,
                        teslaBatteryLevel: "80%",
                        teslaDrive: "D",
                        teslaMedia: "Song",
                        cyclingPower: "250 W",
                        cyclingCadence: "90",
                        runningMetrics: ["Foot pod": .init(speed: 3.5, cadence: 180, distance: 4200)],
                        browserTitle: "Title",
                        gForce: GForce(now: 1.5, recentMax: 2.5, max: 3.5),
                        latestSubscriber: "Subscriber",
                        latestFollower: "Follower")
    }
}
