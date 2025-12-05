import CoreMotion

extension Model {
    func startRealtimeIrlPedometer() {
        guard isLive else {
            return
        }
        guard isRealtimeIrlConfigured(), CMPedometer.isStepCountingAvailable() else {
            return
        }
        guard !pedometerUpdatesActive else {
            return
        }

        pedometerUpdatesActive = true
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self else {
                return
            }
            guard error == nil, let steps = data?.numberOfSteps.intValue else {
                return
            }
            DispatchQueue.main.async {
                self.realtimeIrl?.updatePedometerSteps(steps)
            }
        }
    }

    func stopRealtimeIrlPedometer() {
        guard pedometerUpdatesActive else {
            return
        }
        pedometer.stopUpdates()
        pedometerUpdatesActive = false
    }
}
