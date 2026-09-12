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
@MainActor
private class Workout: NSObject {
    static let shared = Workout()
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var model: Model?

    func isActive() -> Bool {
        workoutSession != nil
    }

    func start(model: Model, type: WatchProtocolWorkoutType) -> Bool {
        self.model = model
        #if targetEnvironment(macCatalyst)
        return false
        #else
        let configuration = HKWorkoutConfiguration()
        let activityType: HKWorkoutActivityType
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
            return false
        }
        workoutBuilder = workoutSession.associatedWorkoutBuilder()
        guard let workoutBuilder else {
            self.workoutSession = nil
            return false
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
        return true
        #endif
    }

    func stop() {
        workoutSession?.stopActivity(with: .now)
    }

    private func handleStateChange(session: HKWorkoutSession,
                                   toState: HKWorkoutSessionState,
                                   fromState: HKWorkoutSessionState,
                                   date: Date)
    {
        guard session === workoutSession else {
            return
        }
        logger.info("workout: State change \(fromState) -> \(toState)")
        switch toState {
        case .stopped:
            guard let workoutBuilder else {
                return
            }
            workoutBuilder.endCollection(withEnd: date) { _, error in
                if let error {
                    logger.info("workout: End collection error \(error)")
                }
                workoutBuilder.finishWorkout { _, error in
                    if let error {
                        logger.info("workout: Finish error \(error)")
                    }
                    session.end()
                }
            }
        case .ended:
            finished(session: session)
        default:
            break
        }
    }

    private func handleError(session: HKWorkoutSession, error: any Error) {
        guard session === workoutSession else {
            return
        }
        logger.info("workout: Error \(error)")
        session.end()
        finished(session: session)
    }

    private func finished(session _: HKWorkoutSession) {
        logger.info("workout: Finished")
        workoutSession = nil
        workoutBuilder = nil
        model?.setIsWorkout(type: nil)
    }
}

@available(iOS 26.0, *)
extension Workout: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ session: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date)
    {
        DispatchQueue.main.async {
            self.handleStateChange(session: session, toState: toState, fromState: fromState, date: date)
        }
    }

    nonisolated func workoutSession(_ session: HKWorkoutSession, didFailWithError error: any Error) {
        DispatchQueue.main.async {
            self.handleError(session: session, error: error)
        }
    }
}

@available(iOS 26.0, *)
extension Workout: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
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

    nonisolated func workoutBuilderDidCollectEvent(_: HKLiveWorkoutBuilder) {}
}

extension Model {
    func startWorkout(type: WatchProtocolWorkoutType) {
        guard #available(iOS 26, *) else {
            makeErrorToast(title: String(localized: "Cannot start workout"),
                           subTitle: String(localized: "Needs iOS 26 or to be started from an Apple Watch"))
            return
        }
        authorizeHealthKit {
            guard !Workout.shared.isActive() else {
                self.makeErrorToast(
                    title: String(localized: "Cannot start workout"),
                    subTitle: String(localized: "The previous workout is still stopping. Try again.")
                )
                return
            }
            if Workout.shared.start(model: self, type: type) {
                self.setIsWorkout(type: type)
            } else {
                self.makeErrorToast(title: String(localized: "Cannot start workout"))
            }
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
        Workout.shared.stop()
        if !Workout.shared.isActive() {
            setIsWorkout(type: nil)
        }
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
