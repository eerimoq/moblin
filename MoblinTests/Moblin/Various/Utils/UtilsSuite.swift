import Foundation
@testable import Moblin
import Testing

struct UtilsSuite {
    @Test(.enabled(if: Locale.current.identifier == "en_SE"))
    func fullDuration() {
        #expect(formatShortDuration(seconds: 0) == "0 secs")
        #expect(formatShortDuration(seconds: 1) == "1 sec")
        #expect(formatShortDuration(seconds: 30) == "30 secs")
        #expect(formatShortDuration(seconds: 60) == "1 min")
        #expect(formatShortDuration(seconds: 120) == "2 min")
        #expect(formatShortDuration(seconds: 3600) == "1 hr")
        #expect(formatShortDuration(seconds: 86400) == "1 day")
        #expect(formatShortDuration(seconds: 7 * 86400) == "7 days")
        #expect(formatShortDuration(seconds: 30 * 86400) == "30 days")
        #expect(formatShortDuration(seconds: 90 * 86400) == "90 days")
    }

    @Test
    func pace() {
        #expect(formatPace(speed: 0, unit: .kilometers) == "- min/km")
        #expect(formatPace(speed: 1, unit: .kilometers) == "16:40 min/km")
        #expect(formatPace(speed: 3, unit: .kilometers) == "5:33 min/km")
        #expect(formatPace(speed: 5, unit: .kilometers) == "3:20 min/km")
        #expect(formatPace(speed: 10, unit: .kilometers) == "1:40 min/km")
        #expect(formatPace(speed: 16.66, unit: .kilometers) == "1:00 min/km")
        #expect(formatPace(speed: 16.667, unit: .kilometers) == "0:59 min/km")
        #expect(formatPace(speed: 0, unit: .miles) == "- min/mi")
        #expect(formatPace(speed: 1, unit: .miles) == "26:49 min/mi")
        #expect(formatPace(speed: 3, unit: .miles) == "8:56 min/mi")
        #expect(formatPace(speed: 5, unit: .miles) == "5:21 min/mi")
        #expect(formatPace(speed: 10, unit: .miles) == "2:40 min/mi")
    }

    @Test
    func paceDefaultsToCurrentMeasurementSystem() {
        let unit: UnitLength = Locale.current.measurementSystem == .metric ? .kilometers : .miles
        #expect(formatPace(speed: 5) == formatPace(speed: 5, unit: unit))
    }

    @Test
    func windSpeed() {
        #expect(formatWindSpeed(speed: Measurement(value: 5, unit: .milesPerHour), unit: .metersPerSecond) ==
            "2 m/s")
        #expect(formatWindSpeed(speed: Measurement(value: 10, unit: .milesPerHour), unit: .metersPerSecond) ==
            "4 m/s")
        #expect(formatWindSpeed(speed: Measurement(value: 5, unit: .milesPerHour), unit: .milesPerHour) ==
            "5 mph")
        #expect(formatWindSpeed(speed: Measurement(value: 10, unit: .milesPerHour), unit: .milesPerHour) ==
            "10 mph")
    }

    @Test
    func windSpeedAndGust() {
        #expect(formatWindAndGustSpeed(speed: Measurement(value: 5, unit: .milesPerHour),
                                       gust: Measurement(value: 10, unit: .milesPerHour),
                                       unit: .metersPerSecond) == "2 (4) m/s")
        #expect(formatWindAndGustSpeed(speed: Measurement(value: 15, unit: .milesPerHour),
                                       gust: Measurement(value: 20, unit: .milesPerHour),
                                       unit: .metersPerSecond) == "6 (8) m/s")
        #expect(formatWindAndGustSpeed(speed: Measurement(value: 5, unit: .milesPerHour),
                                       gust: Measurement(value: 10, unit: .milesPerHour),
                                       unit: .milesPerHour) == "5 (10) mph")
    }

    @Test
    func windSpeedDefaultsToCurrentMeasurementSystem() {
        let unit: UnitSpeed = Locale.current.measurementSystem == .metric ? .metersPerSecond : .milesPerHour
        let speed = Measurement(value: 5, unit: UnitSpeed.milesPerHour)
        let gust = Measurement(value: 10, unit: UnitSpeed.milesPerHour)
        #expect(formatWindSpeed(speed: speed, unit: nil) == formatWindSpeed(speed: speed, unit: unit))
        #expect(formatWindAndGustSpeed(speed: speed, gust: gust, unit: nil)
            == formatWindAndGustSpeed(speed: speed, gust: gust, unit: unit))
    }

    @Test
    func uuidAddEmpty() throws {
        let original = try #require(UUID(uuidString: "00000000-1111-2222-3333-000000000000"))
        let extra = Data()
        let result = try #require(UUID(uuidString: "00000000-1111-2222-3333-000000000000"))
        #expect(original.add(data: extra) == result)
    }

    @Test
    func uuidAddShort() throws {
        let original = try #require(UUID(uuidString: "07080000-0000-0000-0000-010203040506"))
        let extra = Data([0x01, 0x23, 0x45, 0x67])
        let result = try #require(UUID(uuidString: "07080000-0000-0000-0000-010204274A6D"))
        #expect(original.add(data: extra) == result)
    }

    @Test
    func uuidAddLong() throws {
        let original = try #require(UUID(uuidString: "07080000-0000-0000-0000-010203040506"))
        let extra = Data([0x01, 0x23, 0x45, 0x67]) + Data(count: 15)
        let result = try #require(UUID(uuidString: "6E080000-0000-0000-0000-01020305284B"))
        #expect(original.add(data: extra) == result)
    }

    @Test
    func uuidAddByteWrap() throws {
        let original = try #require(UUID(uuidString: "00010000-0000-0000-0000-FAFBFCFDFEFF"))
        let extra = Data([0x01, 0x23, 0x45, 0x67])
        let result = try #require(UUID(uuidString: "00010000-0000-0000-0000-FAFBFD204366"))
        #expect(original.add(data: extra) == result)
    }

    @Test
    func arrayWithCPointers() {
        let data = ["1", "22", "333"]
        data.withCPointers { array in
            let first = array[0]!
            #expect(first[0] == 0x31)
            #expect(first[1] == 0x0)
            let second = array[1]!
            #expect(second[0] == 0x32)
            #expect(second[1] == 0x32)
            #expect(second[2] == 0x0)
            let third = array[2]!
            #expect(third[0] == 0x33)
            #expect(third[1] == 0x33)
            #expect(third[2] == 0x33)
            #expect(third[3] == 0x0)
        }
    }

    @Test
    func getInt64() {
        let data = Data(repeating: 0xFF, count: 8)
        #expect(data.getInt64Be(offset: 0) == -1)
    }

    @Test
    func removeAllWhitespaces() {
        #expect("".removeAllWhitespaces() == "")
        #expect(" ji ji ji ".removeAllWhitespaces() == "jijiji")
        #expect("   ".removeAllWhitespaces() == "")
        #expect("a     a".removeAllWhitespaces() == "aa")
        #expect("""
        fds
        df
        df
        """.removeAllWhitespaces() == "fdsdfdf")
    }

    @Test
    func truncate() {
        #expect("".truncate(length: 5) == "")
        #expect("hi".truncate(length: 5) == "hi")
        #expect("hello".truncate(length: 5) == "hello")
        #expect("hello!".truncate(length: 5) == "he...")
        #expect("hello!".truncate(length: 3) == "...")
        #expect("hello!".truncate(length: 2) == "..")
        #expect("hello!".truncate(length: 0) == "")
    }

    @Test
    func sortedBySearchPrefixPutsPrefixMatchesFirst() {
        let names = ["xqc", "Bob", "abob", "bobby", "carl", "BOBBO"]
        #expect(sortedBySearchPrefix(names, searchText: "bob") { $0 } == [
            "Bob", "bobby", "BOBBO", "xqc", "abob", "carl",
        ])
    }

    @Test
    func sortedBySearchPrefixWithoutMatches() {
        #expect(sortedBySearchPrefix(["c", "a", "b"], searchText: "z") { $0 } == ["c", "a", "b"])
    }
}
