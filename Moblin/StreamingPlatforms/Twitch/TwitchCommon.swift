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
