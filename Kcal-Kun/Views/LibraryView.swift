import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Product.name) private var allProducts: [Product]

    @State private var searchText = ""

    private var favorites: [Product] {
        let base = allProducts.filter { $0.isFavorite }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var myProducts: [Product] {
        let base = allProducts.filter { $0.source == .ocr || $0.source == .manual }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var isEmpty: Bool { favorites.isEmpty && myProducts.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty && searchText.isEmpty {
                    ContentUnavailableView(
                        "Keine Produkte",
                        systemImage: "cart",
                        description: Text("Scanne eine Verpackung oder füge ein Produkt manuell hinzu.")
                    )
                } else {
                    List {
                        if !favorites.isEmpty {
                            Section("Favoriten") {
                                ForEach(favorites) { product in
                                    productRow(product)
                                }
                            }
                        }

                        Section("Meine Produkte") {
                            if myProducts.isEmpty {
                                Text("Noch keine gescannten oder manuellen Produkte.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(myProducts) { product in
                                    productRow(product)
                                }
                                .onDelete { indexSet in
                                    for i in indexSet {
                                        modelContext.delete(myProducts[i])
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Produkt suchen")
                }
            }
            .navigationTitle("Bibliothek")
        }
    }

    private func productRow(_ product: Product) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.body)
                HStack(spacing: 6) {
                    Text("\(Int(product.kcalPer100g)) kcal · \(product.proteinPer100g, specifier: "%.1f")g P")
                    if product.source == .ocr {
                        Text("· Gescannt").foregroundStyle(.blue)
                    } else if product.source == .manual {
                        Text("· Manuell").foregroundStyle(.purple)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                product.isFavorite.toggle()
            } label: {
                Image(systemName: product.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(product.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Product.self, inMemory: true)
}
