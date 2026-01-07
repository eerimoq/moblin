extension Model: RemoteControlWebUIDelegate {
    func remoteControlWebUIGetStatus()
        -> (RemoteControlStatusGeneral, RemoteControlStatusTopLeft, RemoteControlStatusTopRight)
    {
        let (general, topLeft, topRight) = remoteControlStreamerCreateStatus(filter: nil)
        return (general!, topLeft!, topRight!)
    }
}
