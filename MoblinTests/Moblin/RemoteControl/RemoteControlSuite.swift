import Foundation
@testable import Moblin
import Testing
import WeatherKit

struct RemoteControlSuite {
    private func encode(_ request: RemoteControlRequest) throws -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try String(bytes: encoder.encode(request), encoding: .utf8)
    }

    @Test
    func gimbalRequests() throws {
        #expect(try encode(.setGimbalTracking(on: true)) == #"{"setGimbalTracking":{"on":true}}"#)
        #expect(try encode(.setGimbalMovement(x: 1, y: -1)) == #"{"setGimbalMovement":{"x":1,"y":-1}}"#)
        #expect(try encode(.animateGimbal(motion: .kapow)) == #"{"animateGimbal":{"motion":{"kapow":{}}}}"#)
        #expect(try encode(.saveGimbalPreset) == #"{"saveGimbalPreset":{}}"#)
    }

    @Test
    func sendMessageRequest() throws {
        #expect(try encode(.sendMessage(text: "Hello")) == #"{"sendMessage":{"text":"Hello"}}"#)
    }

    @Test
    func musicRequests() throws {
        #expect(try encode(.music(command: .play)) == #"{"music":{"command":{"play":{}}}}"#)
        #expect(try encode(.music(command: .add(title: "Song", user: nil, requestId: nil))) ==
            #"{"music":{"command":{"add":{"title":"Song"}}}}"#)
        #expect(try encode(.music(command: .add(title: "Song", user: "Erik", requestId: nil))) ==
            #"{"music":{"command":{"add":{"title":"Song","user":"Erik"}}}}"#)
        #expect(try encode(.music(command: .add(title: "Song", user: "Erik", requestId: "ORDER1"))) ==
            #"{"music":{"command":{"add":{"requestId":"ORDER1","title":"Song","user":"Erik"}}}}"#)
        #expect(try encode(.music(command: .find(title: "Song"))) ==
            #"{"music":{"command":{"find":{"title":"Song"}}}}"#)
        #expect(try encode(.music(command: .remove(id: "1"))) ==
            #"{"music":{"command":{"remove":{"id":"1"}}}}"#)
        let request = try JSONDecoder().decode(
            RemoteControlRequest.self,
            from: Data(#"{"music":{"command":{"add":{"title":"Song","user":"Erik"}}}}"#.utf8)
        )
        guard case let .music(command: .add(title: title, user: user, requestId: requestId)) = request else {
            Issue.record("not an add")
            return
        }
        #expect(title == "Song")
        #expect(user == "Erik")
        #expect(requestId == nil)
    }

    @Test
    func tipRequests() throws {
        let message = RemoteControlRequest.tip(name: "Erik",
                                               message: "Hi",
                                               kind: .message(amount: "7.00", currency: "USD"),
                                               requestId: "ORDER1")
        #expect(try encode(message) == """
        {"tip":{"kind":{"message":{"amount":"7.00","currency":"USD"}},\
        "message":"Hi","name":"Erik","requestId":"ORDER1"}}
        """)
        let effect = RemoteControlRequest.tip(name: "Erik",
                                              message: "",
                                              kind: .effect(sound: "Bad chili fart"),
                                              requestId: "ORDER2")
        #expect(try encode(effect) == """
        {"tip":{"kind":{"effect":{"sound":"Bad chili fart"}},"message":"","name":"Erik","requestId":"ORDER2"}}
        """)
        let wheelOfLuck = """
        {"tip":{"name":"Erik","message":"Go!","kind":{"wheelOfLuck":{"count":3}},"requestId":"ORDER3"}}
        """
        let request = try JSONDecoder().decode(RemoteControlRequest.self, from: Data(wheelOfLuck.utf8))
        guard case let .tip(name, message, .wheelOfLuck(count), requestId) = request else {
            Issue.record("not a wheel of luck tip")
            return
        }
        #expect(name == "Erik")
        #expect(message == "Go!")
        #expect(count == 3)
        #expect(requestId == "ORDER3")
    }

    @Test
    func musicResponses() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let found = RemoteControlResponse.musicFind(song: RemoteControlMusicFoundSong(
            id: "1440818839",
            title: "Song",
            artist: "Band",
            duration: 213
        ))
        #expect(try String(bytes: encoder.encode(found), encoding: .utf8) ==
            #"{"musicFind":{"song":{"artist":"Band","duration":213,"id":"1440818839","title":"Song"}}}"#)
        #expect(try String(
            bytes: encoder.encode(RemoteControlResponse.musicFind(song: nil)),
            encoding: .utf8
        ) ==
            #"{"musicFind":{}}"#)
    }

    @Test
    func remoteSceneDataVariables() throws {
        let variables = RemoteControlRemoteSceneDataVariables(variables: createVariables())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let encoded = try String(bytes: encoder.encode(variables), encoding: .utf8)
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
          "bonding" : "60% Cellular, 40% WiFi",
          "browserTitle" : "Title",
          "city" : "Malmö",
          "condition" : "clear",
          "conditions" : "sun.max",
          "country" : "Sweden",
          "countryFlag" : "🇸🇪",
          "cyclingCadence" : "90",
          "cyclingPower" : "250 W",
          "cyclingSpeed" : 10,
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
          "systemMonitor" : "12% 300 MB",
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

    @Test
    func stats() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let encoded = try String(bytes: encoder.encode(createRemoteControlStats()), encoding: .utf8)
        #expect(encoded == """
        {
          "activeEnergyBurned" : 350,
          "altitude" : 243.5,
          "altitudeAscent" : 120.25,
          "altitudeDescent" : 80.5,
          "area" : "Malmö",
          "averageSpeed" : 7.25,
          "city" : "Malmö",
          "country" : "Sweden",
          "countryFlag" : "🇸🇪",
          "cyclingCadence" : 90,
          "cyclingPower" : 250,
          "cyclingSpeed" : 10,
          "date" : 745043166,
          "distance" : 1700.75,
          "feelsLikeTemperature" : 17,
          "gForce" : {
            "max" : 3.5,
            "now" : 1.5,
            "recentMax" : 2.5
          },
          "heartRates" : {
            "Belt" : null,
            "Watch" : 75
          },
          "latitude" : 55.60587,
          "longitude" : 13.00073,
          "neighborhood" : "Möllevången",
          "power" : 210,
          "slopePercent" : 5.5,
          "speed" : 5.5,
          "splitAltitudeAscent" : 40.75,
          "splitAltitudeDescent" : 30.25,
          "splitDistance" : 5400.5,
          "state" : "Skåne",
          "stepCount" : 8000,
          "temperature" : 22,
          "timeZone" : "Europe\\/Stockholm",
          "windGust" : 8.5,
          "windSpeed" : 3,
          "workoutDistance" : 4200
        }
        """)
    }

    @Test
    func statsDecode() throws {
        let stats = createRemoteControlStats()
        let encoded = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(RemoteControlStats.self, from: encoded)
        #expect(decoded.date == stats.date)
        #expect(decoded.timeZone == "Europe/Stockholm")
        #expect(decoded.speed == 5.5)
        #expect(decoded.averageSpeed == 7.25)
        #expect(decoded.altitude == 243.5)
        #expect(decoded.latitude == 55.60587)
        #expect(decoded.longitude == 13.00073)
        #expect(decoded.distance == 1700.75)
        #expect(decoded.splitDistance == 5400.5)
        #expect(decoded.slopePercent == 5.5)
        #expect(decoded.altitudeAscent == 120.25)
        #expect(decoded.altitudeDescent == 80.5)
        #expect(decoded.splitAltitudeAscent == 40.75)
        #expect(decoded.splitAltitudeDescent == 30.25)
        #expect(decoded.temperature == 22)
        #expect(decoded.feelsLikeTemperature == 17)
        #expect(decoded.windSpeed == 3)
        #expect(decoded.windGust == 8.5)
        #expect(decoded.country == "Sweden")
        #expect(decoded.countryFlag == "🇸🇪")
        #expect(decoded.state == "Skåne")
        #expect(decoded.area == "Malmö")
        #expect(decoded.city == "Malmö")
        #expect(decoded.neighborhood == "Möllevången")
        #expect(decoded.heartRates == ["Watch": 75, "Belt": nil])
        #expect(decoded.activeEnergyBurned == 350)
        #expect(decoded.workoutDistance == 4200)
        #expect(decoded.power == 210)
        #expect(decoded.stepCount == 8000)
        #expect(decoded.cyclingPower == 250)
        #expect(decoded.cyclingCadence == 90)
        #expect(decoded.cyclingSpeed == 10)
        #expect(decoded.gForce?.now == 1.5)
        #expect(decoded.gForce?.recentMax == 2.5)
        #expect(decoded.gForce?.max == 3.5)
    }

    private func createRemoteControlStats() -> RemoteControlStats {
        RemoteControlStats(date: Date(timeIntervalSince1970: 1_723_350_366),
                           timeZone: "Europe/Stockholm",
                           speed: 5.5,
                           averageSpeed: 7.25,
                           altitude: 243.5,
                           latitude: 55.60587,
                           longitude: 13.00073,
                           distance: 1700.75,
                           splitDistance: 5400.5,
                           slopePercent: 5.5,
                           altitudeAscent: 120.25,
                           altitudeDescent: 80.5,
                           splitAltitudeAscent: 40.75,
                           splitAltitudeDescent: 30.25,
                           temperature: 22,
                           feelsLikeTemperature: 17,
                           windSpeed: 3,
                           windGust: 8.5,
                           country: "Sweden",
                           countryFlag: "🇸🇪",
                           state: "Skåne",
                           area: "Malmö",
                           city: "Malmö",
                           neighborhood: "Möllevången",
                           heartRates: ["Watch": 75, "Belt": nil],
                           activeEnergyBurned: 350,
                           workoutDistance: 4200,
                           power: 210,
                           stepCount: 8000,
                           cyclingPower: 250,
                           cyclingCadence: 90,
                           cyclingSpeed: 10,
                           gForce: GForce(now: 1.5, recentMax: 2.5, max: 3.5))
    }

    private func createVariables() -> Variables {
        Variables(timestamp: .now,
                  bitrate: "5000 kbps",
                  bitrateAndTotal: "5000 kbps, 1.2 GB",
                  bonding: "60% Cellular, 40% WiFi",
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
                  condition: .clear,
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
                  cyclingSpeed: 10,
                  runningMetrics: ["Foot pod": .init(speed: 3.5, cadence: 180, distance: 4200)],
                  browserTitle: "Title",
                  gForce: GForce(now: 1.5, recentMax: 2.5, max: 3.5),
                  latestSubscriber: "Subscriber",
                  latestFollower: "Follower",
                  systemMonitor: "12% 300 MB")
    }
}
