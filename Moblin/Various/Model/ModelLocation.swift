import CoreLocation

extension Model {
    func updateLocation() {
        var location = locationManager.status()
        if let realtimeIrl {
            location += realtimeIrl.status()
        }
        if location != statusTopRight.location {
            statusTopRight.location = location
        }
    }

    func reloadLocation() {
        locationManager.stop()
        if isLocationEnabled() {
            locationManager.start(accuracy: database.location.desiredAccuracy,
                                  distanceFilter: database.location.distanceFilter,
                                  onUpdate: handleLocationUpdate)
        }
        reloadRealtimeIrl()
    }

    private func resetDistance() {
        database.location.distance = 0.0
        database.location.splitDistance = 0.0
        database.location.altitudeAscent = 0.0
        database.location.altitudeDescent = 0.0
        database.location.splitAltitudeAscent = 0.0
        database.location.splitAltitudeDescent = 0.0
        latestKnownLocation = nil
    }

    func resetSplitDistance() {
        database.location.splitDistance = 0.0
        database.location.splitAltitudeAscent = 0.0
        database.location.splitAltitudeDescent = 0.0
    }

    func resetLocationData() {
        resetDistance()
        resetAverageSpeed()
        resetSlope()
    }

    func isLocationEnabled() -> Bool {
        database.location.enabled
    }

    private func handleLocationUpdate(location: CLLocation) {
        guard isLive else {
            return
        }
        guard !isLocationInPrivacyRegion(location: location) else {
            return
        }
        realtimeIrl?.update(location: location)
    }

    func isLocationInPrivacyRegion(location: CLLocation) -> Bool {
        for region in database.location.privacyRegions
            where region.contains(coordinate: location.coordinate)
        {
            return true
        }
        return false
    }

    func getLatestKnownLocation() -> (Double, Double)? {
        if let location = locationManager.getLatestKnownLocation() {
            (location.coordinate.latitude, location.coordinate.longitude)
        } else {
            nil
        }
    }

    func isRealtimeIrlConfigured() -> Bool {
        stream.realtimeIrlEnabled && !stream.realtimeIrlBaseUrl.isEmpty && !stream.realtimeIrlPushKey
            .isEmpty
    }

    func reloadRealtimeIrl() {
        realtimeIrl?.stop()
        realtimeIrl = nil
        if isRealtimeIrlConfigured() {
            realtimeIrl = RealtimeIrl(baseUrl: stream.realtimeIrlBaseUrl, pushKey: stream.realtimeIrlPushKey)
        }
    }

    func updateDistance() {
        let location = locationManager.getLatestKnownLocation()
        if let latestKnownLocation {
            let distance = location?.distance(from: latestKnownLocation) ?? 0
            if distance > latestKnownLocation.horizontalAccuracy {
                database.location.distance += distance
                database.location.splitDistance += distance
                updateAltitude(from: latestKnownLocation, to: location)
                self.latestKnownLocation = location
            }
        } else {
            latestKnownLocation = location
        }
    }

    private func updateAltitude(from: CLLocation, to: CLLocation?) {
        guard let to, from.verticalAccuracy >= 0, to.verticalAccuracy >= 0 else {
            return
        }
        let deltaAltitude = to.altitude - from.altitude
        guard abs(deltaAltitude) > max(from.verticalAccuracy, to.verticalAccuracy) else {
            return
        }
        if deltaAltitude > 0 {
            database.location.altitudeAscent += deltaAltitude
            database.location.splitAltitudeAscent += deltaAltitude
        } else {
            database.location.altitudeDescent += -deltaAltitude
            database.location.splitAltitudeDescent += -deltaAltitude
        }
    }

    func resetSlope() {
        slopePercent = 0.0
        previousSlopeAltitude = nil
        previousSlopeDistance = database.location.distance
    }

    func updateSlope() {
        guard let location = locationManager.getLatestKnownLocation() else {
            return
        }
        let deltaDistance = database.location.distance - previousSlopeDistance
        guard deltaDistance != 0 else {
            return
        }
        previousSlopeDistance = database.location.distance
        let deltaAltitude = location.altitude - (previousSlopeAltitude ?? location.altitude)
        previousSlopeAltitude = location.altitude
        slopePercent = 0.7 * slopePercent + 0.3 * (100 * deltaAltitude / deltaDistance)
    }

    func resetAverageSpeed() {
        averageSpeed = 0.0
        averageSpeedStartTime = .now
        averageSpeedStartDistance = database.location.distance
    }

    func updateAverageSpeed(now: ContinuousClock.Instant) {
        let distance = database.location.distance - averageSpeedStartDistance
        let elapsed = averageSpeedStartTime.duration(to: now)
        averageSpeed = distance / elapsed.seconds
    }

    func isShowingStatusLocation() -> Bool {
        database.show.location && isLocationEnabled()
    }
}
