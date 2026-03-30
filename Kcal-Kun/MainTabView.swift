import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Tagebuch", systemImage: "book") {
                DiaryView()
            }
            Tab("Bibliothek", systemImage: "books.vertical") {
                LibraryView()
            }
            Tab("Scanner", systemImage: "camera.viewfinder") {
                ScannerView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Product.self, DiaryEntry.self], inMemory: true)
}
