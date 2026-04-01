import Foundation
import HealthKit
import Observation

@Observable
@MainActor
final class HealthKitService {
    var workoutKcal: Double = 0
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
            await fetchWorkoutKcal(for: Date())
        } catch {
            print("[HealthKit] Authorization failed: \(error)")
        }
    }

    func fetchWorkoutKcals(forLast days: Int) async -> [Date: Double] {
        guard HKHealthStore.isHealthDataAvailable() else { return [:] }
        let today     = Calendar.current.startOfDay(for: Date())
        let startDate = Calendar.current.date(byAdding: .day, value: -(days - 1), to: today)!
        let endDate   = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: endDate, options: .strictStartDate
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
        var result: [Date: Double] = [:]
        for workout in workouts ?? [] {
            let day  = Calendar.current.startOfDay(for: workout.startDate)
            let kcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            result[day, default: 0] += kcal * 0.9
        }
        return result
    }

    func fetchWorkoutKcal(for date: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay   = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay, end: endOfDay, options: .strictStartDate
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
        workoutKcal = total * 0.9  // 10% Abschlag
    }
}
