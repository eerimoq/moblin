@testable import Moblin
import Testing

struct TwitchRaidHistorySuite {
    @Test func appendNewestFirst() {
        var channels: [SettingsStreamTwitchRaidChannel] = []
        channels = appendTwitchRaidChannel(channels, channelId: "1", channelName: "One")
        channels = appendTwitchRaidChannel(channels, channelId: "2", channelName: "Two")
        #expect(channels.map(\.channelId) == ["2", "1"])
        #expect(channels.map(\.channelName) == ["Two", "One"])
    }

    @Test func appendExistingMovesToFront() {
        var channels: [SettingsStreamTwitchRaidChannel] = []
        channels = appendTwitchRaidChannel(channels, channelId: "1", channelName: "One")
        channels = appendTwitchRaidChannel(channels, channelId: "2", channelName: "Two")
        channels = appendTwitchRaidChannel(channels, channelId: "1", channelName: "New name")
        #expect(channels.count == 2)
        #expect(channels.map(\.channelId) == ["1", "2"])
        #expect(channels[0].channelName == "New name")
    }

    @Test func appendDropsOldest() {
        var channels: [SettingsStreamTwitchRaidChannel] = []
        for index in 0 ..< maximumNumberOfTwitchRaidChannels + 5 {
            channels = appendTwitchRaidChannel(channels, channelId: "\(index)", channelName: "\(index)")
        }
        #expect(channels.count == maximumNumberOfTwitchRaidChannels)
        #expect(channels.first?.channelId == "\(maximumNumberOfTwitchRaidChannels + 4)")
        #expect(channels.last?.channelId == "5")
    }
}
