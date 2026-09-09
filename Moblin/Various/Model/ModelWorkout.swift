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
        types.insert(.quantityType(forIdentifier: .cyclingCadence)!)
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

    func start(model: Model, type: WatchProtocolWorkoutType) {
        self.model = model
        stop()
        #if !targetEnvironment(macCatalyst)
        let configuration = HKWorkoutConfiguration()
        var activityType: HKWorkoutActivityType
        let addStepCount: Bool
        let addCyclingMetrics: Bool
        switch type {
        case .walking:
            activityType = .walking
            addStepCount = true
            addCyclingMetrics = false
        case .running:
            activityType = .running
            addStepCount = true
            addCyclingMetrics = false
        case .cycling:
            activityType = .cycling
            addStepCount = false
            addCyclingMetrics = true
        }
        configuration.activityType = activityType
        configuration.locationType = .outdoor
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
        if addCyclingMetrics {
            dataSource.enableCollection(
                for: HKQuantityType.quantityType(forIdentifier: .cyclingPower)!,
                predicate: nil
            )
            dataSource.enableCollection(
                for: HKQuantityType.quantityType(forIdentifier: .cyclingCadence)!,
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

    func isWorkoutDeviceProvidingCycling() -> Bool {
        guard let latestWorkoutDeviceCyclingUpdate else {
            return false
        }
        return latestWorkoutDeviceCyclingUpdate.duration(to: .now) < .seconds(5)
    }

    func stopWorkout() {
        guard #available(iOS 26, *) else {
            return
        }
        setIsWorkout(type: nil)
        Workout.shared.stop()
    }

    private func authorizeHealthKit(completion: @escaping @MainActor () -> Void) {
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
        ]
        healthStore.requestAuthorization(toShare: typesToShare, read: types()) { _, _ in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
