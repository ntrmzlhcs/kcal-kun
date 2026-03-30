import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \Product.name) private var products: [Product]

    var body: some View {
        NavigationStack {
            Group {
                if products.isEmpty {
                    ContentUnavailableView(
                        "Keine Produkte",
                        systemImage: "cart",
                        description: Text("Scanne eine Verpackung oder füge ein Produkt manuell hinzu.")
                    )
                } else {
                    List(products) { product in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.body)
                            Text("\(product.kcalPer100g, specifier: "%.0f") kcal · \(product.proteinPer100g, specifier: "%.1f")g Protein")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Bibliothek")
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Product.self, inMemory: true)
}
