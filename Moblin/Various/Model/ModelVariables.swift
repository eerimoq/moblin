import Foundation

extension Model {
    func createVariables(now: Date, timestamp: ContinuousClock.Instant) -> Variables {
        let location = locationManager.getLatestKnownLocation()
        let weather = weatherManager.getLatestWeather()?.currentWeather
        let placemark = geographyManager.getLatestPlacemark()
        return Variables(
            timestamp: timestamp,
            bitrate: bitrate.speedMbpsOneDecimal,
            bitrateAndTotal: bitrate.speedAndTotal,
            resolution: currentResolution,
            fps: currentFps,
            date: now,
            debugOverlayLines: debugOverlay.debugLines,
            speed: location?.speed ?? 0,
            averageSpeed: averageSpeed,
            altitude: location?.altitude ?? 0,
            distance: database.location.distance,
            splitDistance: database.location.splitDistance,
            altitudeAscent: database.location.altitudeAscent,
            altitudeDescent: database.location.altitudeDescent,
            splitAltitudeAscent: database.location.splitAltitudeAscent,
            splitAltitudeDescent: database.location.splitAltitudeDescent,
            slope: "\(Int(slopePercent))%",
            conditions: weather?.symbolName,
            condition: weather?.condition,
            temperature: weather?.temperature,
            feelsLikeTemperature: weather?.apparentTemperature,
            windSpeed: weather?.wind.speed,
            windGust: weather?.wind.gust,
            country: placemark?.country ?? "",
            countryFlag: emojiFlag(countryCode: placemark?.isoCountryCode),
            state: placemark?.administrativeArea,
            area: placemark?.subAdministrativeArea,
            city: placemark?.locality,
            neighborhood: placemark?.subLocality,
            muted: isMuteOn,
            heartRates: heartRates,
            activeEnergyBurned: workoutActiveEnergyBurned,
            workoutDistance: workoutDistance,
            power: workoutPower,
            stepCount: workoutStepCount,
            teslaBatteryLevel: textEffectTeslaBatteryLevel(),
            teslaDrive: textEffectTeslaDrive(),
            teslaMedia: textEffectTeslaMedia(),
            cyclingPower: "\(cyclingPower) W",
            cyclingCadence: "\(cyclingCadence)",
            runningMetrics: runningMetrics,
            browserTitle: getBrowserTitle(),
            gForce: gForceManager?.getLatest(),
            latestSubscriber: latestSubscriber,
            latestFollower: latestFollower
        )
    }

    private func getBrowserTitle() -> String {
        if showBrowser {
            getWebBrowser().title ?? ""
        } else {
            ""
        }
    }
}
