import Foundation
import HealthKit
import Observation

@Observable
@MainActor
final class HealthKitService {
    var workoutKcalToday: Double = 0
    var isAuthorized: Bool = false

    private let store = HKHealthStore()

    func requestAuthorizationAndFetch() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(
                toShare: [],
                read: [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
            )
            isAuthorized = true
            await fetchTodayWorkoutKcal()
        } catch {
            print("[HealthKit] Authorization failed: \(error)")
        }
    }

    func fetchTodayWorkoutKcal() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay, end: Date(), options: .strictStartDate
        )
        let workouts = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
        let total = (workouts ?? []).reduce(0.0) {
            $0 + ($1.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
        }
        workoutKcalToday = total * 0.9  // 10% Abschlag
    }
}
