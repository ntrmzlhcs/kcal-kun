import SwiftUI

struct DiaryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Tagebuch",
                systemImage: "book",
                description: Text("Kommt in Phase 3.")
            )
            .navigationTitle("Tagebuch")
        }
    }
}

#Preview {
    DiaryView()
}
