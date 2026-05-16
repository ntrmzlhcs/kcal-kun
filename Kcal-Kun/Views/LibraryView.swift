import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Product.name) private var allProducts: [Product]

    @State private var searchText = ""
    @State private var showManualEntry = false

    private var favorites: [Product] {
        let base = allProducts.filter { $0.isFavorite }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var myProducts: [Product] {
        let base = allProducts.filter { $0.source == .ocr || $0.source == .manual || $0.source == .dish }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var isEmpty: Bool { favorites.isEmpty && myProducts.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Group {
                    if isEmpty && searchText.isEmpty {
                        emptyState
                    } else {
                        productList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Bibliothek")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showManualEntry = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.warmBrown)
                    }
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualProductEntryView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            MascotView(size: 80, mood: .sleep, tone: .beige)
            Text("Noch keine Produkte")
                .font(.display(22))
                .foregroundStyle(Color.inkPrimary)
            Text("Scanne eine Verpackung oder füge ein Produkt manuell hinzu.")
                .font(.system(size: 14))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showManualEntry = true
            } label: {
                Label("Manuell hinzufügen", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.terra)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.terra.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.warmBrown)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schweizer Nährwertdatenbank")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text("Die App enthält ~1'200 Grundnahrungsmittel und Zutaten (BLV). Suche im Tagebuch danach und füge sie direkt hinzu — ohne Scannen.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(Color.beige.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0x7C5E3C).opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 28)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Product List

    private var productList: some View {
        List {
            if !favorites.isEmpty {
                Section {
                    ForEach(favorites) { product in
                        productRow(product)
                    }
                } header: {
                    SectionLabel(text: "Favoriten")
                        .padding(.top, 4)
                }
                .listRowBackground(Color.cardBackground)
                .listRowSeparatorTint(Color.inkDivider)
            }

            Section {
                if myProducts.isEmpty {
                    HStack {
                        MascotView(size: 24, mood: .think, tone: .beige)
                        Text("Noch keine gescannten oder manuellen Produkte.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(myProducts) { product in
                        productRow(product)
                    }
                    .onDelete { indexSet in
                        for i in indexSet { modelContext.delete(myProducts[i]) }
                        try? modelContext.save()
                    }
                }
            } header: {
                SectionLabel(text: "Meine Produkte")
                    .padding(.top, 4)
            }
            .listRowBackground(Color.cardBackground)
            .listRowSeparatorTint(Color.inkDivider)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Produkt suchen")
    }

    // MARK: - Product Row

    private func productRow(_ product: Product) -> some View {
        HStack(spacing: 12) {
            // Letter avatar
            ZStack {
                Circle()
                    .fill(product.source == .preloaded ? Color.beige : Color.terra.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(String(product.name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.warmBrown)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                HStack(spacing: 6) {
                    Text("\(Int(product.kcalPer100g)) kcal · \(product.proteinPer100g, specifier: "%.1f")g P")
                        .foregroundStyle(Color.inkSecondary)
                    sourceTag(for: product)
                }
                .font(.system(size: 11))
            }

            Spacer()

            Button {
                product.isFavorite.toggle()
            } label: {
                Image(systemName: product.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(product.isFavorite ? Color.amber : Color.inkTertiary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func sourceTag(for product: Product) -> some View {
        switch product.source {
        case .ocr:
            Text("· Gescannt").foregroundStyle(Color.terra)
        case .dish:
            Text("· Gericht").foregroundStyle(Color.forest)
        case .manual:
            Text("· Manuell").foregroundStyle(Color.warmBrown)
        default:
            EmptyView()
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Product.self, inMemory: true)
}
