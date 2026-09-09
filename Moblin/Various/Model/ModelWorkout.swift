import HealthKit
import WatchConnectivity

private func types() -> Set<HKSampleType> {
    var types: Set<HKSampleType> = [
        .quantityType(forIdentifier: .heartRate)!,
        .quantityType(forIdentifier: .distanceCycling)!,
        .quantityType(forIdentifier: .distanceWalkingRunning)!,
        .quantityType(forIdentifier: .stepCount)!,
        .quantityType(forIdentifier: .activeEnergyBurned)!,
        .quantityType(forIdentifier: .runningPower)!,
    ]
    if #available(iOS 17.0, *) {
        types.insert(.quantityType(forIdentifier: .cyclingPower)!)
    }
    return types
}

@available(iOS 26.0, *)
class Workout: NSObject, @unchecked Sendable {
    static let shared = Workout()
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var model: Model?
    private var latestSampleTimes: [HKQuantityTypeIdentifier: ContinuousClock.Instant] = [:]

    func start(model: Model, type: WatchProtocolWorkoutType) {
        self.model = model
        stop()
        #if !targetEnvironment(macCatalyst)
        let configuration = HKWorkoutConfiguration()
        var activityType: HKWorkoutActivityType
        let addStepCount: Bool
        switch type {
        case .walking:
            activityType = .walking
            addStepCount = true
        case .running:
            activityType = .running
            addStepCount = true
        case .cycling:
            activityType = .cycling
            addStepCount = false
        }
        configuration.activityType = activityType
        configuration.locationType = .outdoor
        latestSampleTimes.removeAll()
        workoutSession = try? HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        guard let workoutSession else {
            return
        }
        workoutBuilder = workoutSession.associatedWorkoutBuilder()
        guard let workoutBuilder else {
            return
        }
        let dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        if addStepCount {
            dataSource.enableCollection(
                for: HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                predicate: nil
            )
        }
        workoutBuilder.dataSource = dataSource
        workoutSession.delegate = self
        workoutSession.startActivity(with: .now)
        workoutBuilder.delegate = self
        workoutBuilder.beginCollection(withStart: .now) { _, _ in }
        #endif
    }

    func stop() {
        workoutBuilder?.finishWorkout { _, _ in }
        workoutSession?.end()
    }

    func add(heartRate: Int) {
        add(identifier: .heartRate,
            unit: .count().unitDivided(by: .minute()),
            value: Double(heartRate))
    }

    func add(cyclingPower: Int) {
        add(identifier: .cyclingPower, unit: .watt(), value: Double(cyclingPower))
    }

    func add(cyclingCadence: Int) {
        add(identifier: .cyclingCadence,
            unit: .count().unitDivided(by: .minute()),
            value: Double(cyclingCadence))
    }

    private func add(identifier: HKQuantityTypeIdentifier, unit: HKUnit, value: Double) {
        guard let workoutBuilder, workoutSession?.state == .running else {
            return
        }
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return
        }
        let now = ContinuousClock.now
        if let latest = latestSampleTimes[identifier], latest.duration(to: now) < .seconds(1) {
            return
        }
        latestSampleTimes[identifier] = now
        let date = Date.now
        let sample = HKQuantitySample(type: quantityType,
                                      quantity: HKQuantity(unit: unit, doubleValue: value),
                                      start: date,
                                      end: date)
        workoutBuilder.add([sample]) { _, _ in }
    }
}

@available(iOS 26.0, *)
extension Workout: HKWorkoutSessionDelegate {
    func workoutSession(_: HKWorkoutSession,
                        didChangeTo _: HKWorkoutSessionState,
                        from _: HKWorkoutSessionState,
                        date _: Date) {}

    func workoutSession(_: HKWorkoutSession, didFailWithError _: any Error) {}
}

@available(iOS 26.0, *)
extension Workout: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>)
    {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else {
                continue
            }
            guard let statistics = workoutBuilder.statistics(for: quantityType) else {
                continue
            }
            DispatchQueue.main.async {
                self.model?.handleWorkout(stats: WatchProtocolWorkoutStats(statistics: statistics))
            }
        }
    }

    func workoutBuilderDidCollectEvent(_: HKLiveWorkoutBuilder) {}
}

extension Model {
    func startWorkout(type: WatchProtocolWorkoutType) {
        guard #available(iOS 26, *) else {
            makeErrorToast(title: String(localized: "Cannot start workout"),
                           subTitle: String(localized: "Needs iOS 26 or to be started from an Apple Watch"))
            return
        }
        authorizeHealthKit {
            self.setIsWorkout(type: type)
            Workout.shared.start(model: self, type: type)
        }
    }

    func stopWorkout() {
        guard #available(iOS 26, *) else {
            return
        }
        setIsWorkout(type: nil)
        Workout.shared.stop()
    }

    func addWorkoutHeartRate(_ heartRate: Int) {
        guard #available(iOS 26, *) else {
            return
        }
        Workout.shared.add(heartRate: heartRate)
    }

    func addWorkoutCyclingPower(_ power: Int) {
        guard #available(iOS 26, *) else {
            return
        }
        Workout.shared.add(cyclingPower: power)
    }

    func addWorkoutCyclingCadence(_ cadence: Int) {
        guard #available(iOS 26, *) else {
            return
        }
        Workout.shared.add(cyclingCadence: cadence)
    }

    private func authorizeHealthKit(completion: @escaping @MainActor () -> Void) {
        var typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        ]
        if #available(iOS 17.0, *) {
            typesToShare.insert(HKQuantityType.quantityType(forIdentifier: .cyclingPower)!)
            typesToShare.insert(HKQuantityType.quantityType(forIdentifier: .cyclingCadence)!)
        }
        healthStore.requestAuthorization(toShare: typesToShare, read: types()) { _, _ in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
