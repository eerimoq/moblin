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
class Workout: NSObject {
    static let shared = Workout()
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var model: Model?

    func start(model: Model, type: WatchProtocolWorkoutType) {
        self.model = model
        stop()
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
                var stats = WatchProtocolWorkoutStats()
                switch statistics.quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    if let heartRate = statistics.mostRecentQuantity()?
                        .doubleValue(for: .count().unitDivided(by: HKUnit.minute()))
                    {
                        stats.heartRate = Int(heartRate)
                    }
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    if let activeEnergyBurned = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        stats.activeEnergyBurned = Int(activeEnergyBurned)
                    }
                case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
                     HKQuantityType.quantityType(forIdentifier: .distanceCycling):
                    if let distance = statistics.sumQuantity()?.doubleValue(for: .meter()) {
                        stats.distance = Int(distance)
                    }
                case HKQuantityType.quantityType(forIdentifier: .stepCount):
                    if let stepCount = statistics.sumQuantity()?.doubleValue(for: .count()) {
                        stats.stepCount = Int(stepCount)
                    }
                case HKQuantityType.quantityType(forIdentifier: .runningPower):
                    if let power = statistics.mostRecentQuantity()?.doubleValue(for: .watt()) {
                        stats.power = Int(power)
                    }
                default:
                    break
                }
                self.model?.handleWorkout(stats: stats)
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
            DispatchQueue.main.async {
                self.setIsWorkout(type: type)
                Workout.shared.start(model: self, type: type)
            }
        }
    }

    func stopWorkout() {
        guard #available(iOS 26, *) else {
            return
        }
        setIsWorkout(type: nil)
        Workout.shared.stop()
    }

    private func authorizeHealthKit(completion: @escaping () -> Void) {
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
        ]
        healthStore.requestAuthorization(toShare: typesToShare, read: types()) { _, _ in
            completion()
        }
    }
}
