import MapKit

extension SettingsPrivacyRegion {
    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        cos((latitude - coordinate.latitude).toRadians()) >
            cos((latitudeDelta / 2.0).toRadians()) &&
            cos((longitude - coordinate.longitude).toRadians()) >
            cos((longitudeDelta / 2.0).toRadians())
    }
}

func toLatitudeDeltaDegrees(meters: Double) -> Double {
    return 360 * meters / 40_075_000
}

func toLongitudeDeltaDegrees(meters: Double, latitudeDegrees: Double) -> Double {
    return 360 * meters / (40_075_000 * cos(latitudeDegrees.toRadians()))
}

extension CLLocationCoordinate2D {
    func translateMeters(x: Double, y: Double) -> CLLocationCoordinate2D {
        let latitudeDelta = toLatitudeDeltaDegrees(meters: y)
        var newLatitude = (latitude < 0 ? 360 + latitude : latitude) + latitudeDelta
        newLatitude -= Double(360 * (Int(newLatitude) / 360))
        if newLatitude > 270 {
            newLatitude -= 360
        } else if newLatitude > 90 {
            newLatitude = 180 - newLatitude
        }
        let longitudeDelta = toLongitudeDeltaDegrees(meters: x, latitudeDegrees: latitude)
        var newLongitude = (longitude < 0 ? 360 + longitude : longitude) + longitudeDelta
        newLongitude -= Double(360 * (Int(newLongitude) / 360))
        if newLongitude > 180 {
            newLongitude = newLongitude - 360
        }
        return .init(latitude: newLatitude, longitude: newLongitude)
    }
}

extension MKCoordinateRegion: @retroactive Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        if lhs.center.latitude != rhs.center.latitude || lhs.center.longitude != rhs.center.longitude {
            return false
        }
        if lhs.span.latitudeDelta != rhs.span.latitudeDelta || lhs.span.longitudeDelta != rhs.span
            .longitudeDelta
        {
            return false
        }
        return true
    }
}
