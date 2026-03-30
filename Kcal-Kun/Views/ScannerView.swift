import SwiftUI

struct ScannerView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Scanner",
                systemImage: "camera.viewfinder",
                description: Text("Kommt in Phase 2.")
            )
            .navigationTitle("Scanner")
        }
    }
}

#Preview {
    ScannerView()
}
