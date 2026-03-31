import SwiftUI
import SwiftData

@main
struct KcalKunApp: App {
    let modelContainer: ModelContainer
    @State private var healthKit = HealthKitService()

    init() {
        do {
            modelContainer = try ModelContainer(for: Product.self, DiaryEntry.self, UserProfile.self)
        } catch {
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    await DataSeeder.seedIfNeeded(context: modelContainer.mainContext)
                    await healthKit.requestAuthorizationAndFetch()
                }
        }
        .modelContainer(modelContainer)
        .environment(healthKit)
    }
}
