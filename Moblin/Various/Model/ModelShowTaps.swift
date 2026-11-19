extension Model {
    func updateShowTaps() {
        showTaps.update(enabled: database.debug.showTaps)
    }
}
