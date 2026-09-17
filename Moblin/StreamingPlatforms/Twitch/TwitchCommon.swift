import Foundation

func twitchTierAsNumber(tier: String) -> Int {
    switch tier {
    case "1000":
        1
    case "2000":
        2
    case "3000":
        3
    default:
        1
    }
}

func makeTwitchEmoteUrls(id: String) -> (moving: URL, still: URL)? {
    guard let moving = URL(string: "https://static-cdn.jtvnw.net/emoticons/v2/\(id)/default/dark/3.0"),
          let still = URL(string: "https://static-cdn.jtvnw.net/emoticons/v2/\(id)/static/dark/3.0")
    else {
        return nil
    }
    return (moving, still)
}
