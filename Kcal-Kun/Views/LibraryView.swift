import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext

    // Favoriten via SwiftData-Predicate → SQLite-Lazy-Loading. Bei wachsenden
    // Bibliotheken (5'000+ Items aus Backup-Restore) zieht die Favoriten-Liste
    // nicht mehr alle Items in den RAM. Filter-Suche bleibt clientside in
    // Memory (siehe Suche-Computed-Property unten) — bei typisch <50 Favoriten
    // ein vernachlässigbarer Cost.
    @Query(filter: #Predicate<Product> { $0.isFavorite }, sort: \Product.name)
    private var favoriteProducts: [Product]

    // Restliche Produkte (alle Sources, Filter passiert in Memory).
    // Source-Filtering via #Predicate ist mit dem aktuellen `ProductSource`-
    // Enum noch nicht trivial — Migration auf rohstring-basierte Spalte oder
    // Multi-Query-Pattern wäre für eine 1.1 ein lohnender Folge-Schritt.
    @Query(sort: \Product.name) private var allProducts: [Product]

    @State private var searchText = ""
    @State private var showManualEntry = false
    @State private var selectedProduct: Product? = nil
    @Environment(\.coachmarkDemoMode) private var coachmarkDemo

    private var favorites: [Product] {
        guard !searchText.isEmpty else { return favoriteProducts }
        return favoriteProducts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var myProducts: [Product] {
        let base = allProducts.filter { $0.source == .ocr || $0.source == .manual || $0.source == .dish || $0.source == .barcode }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// BLV-/Preloaded-Produkte, die zur aktuellen Suche passen.
    /// Nur sichtbar wenn aktiv gesucht wird; auf 50 Treffer begrenzt.
    private var blvSearchResults: [Product] {
        guard !searchText.isEmpty else { return [] }
        return Array(
            allProducts
                .filter {
                    ($0.source == .blvApi || $0.source == .preloaded)
                    && !$0.isFavorite
                    && $0.name.localizedCaseInsensitiveContains(searchText)
                }
                .prefix(50)
        )
    }

    private var isEmpty: Bool { favorites.isEmpty && myProducts.isEmpty }

    private var hasNoResults: Bool {
        !searchText.isEmpty
        && favorites.isEmpty
        && myProducts.isEmpty
        && blvSearchResults.isEmpty
    }

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
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Produkt suchen"
            )
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
                    .accessibilityLabel("Produkt manuell erfassen")
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualProductEntryView()
            }
            .sheet(item: $selectedProduct) { product in
                ProductDetailView(product: product)
                    .presentationDetents([.large])
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
            if coachmarkDemo {
                // Während der Tour Demo-Favoriten zeigen statt echter Daten
                Section {
                    ForEach(Array(CoachmarkDemoData.demoFavorites.enumerated()), id: \.element.id) { idx, fav in
                        demoFavoriteRow(fav)
                            .coachmarkTargetIf(idx == 0, .libraryFavorites)
                    }
                } header: {
                    SectionLabel(text: "Favoriten")
                        .padding(.top, 4)
                }
                .listRowBackground(Color.cardBackground)
                .listRowSeparatorTint(Color.inkDivider)
            } else if !favorites.isEmpty {
                Section {
                    ForEach(favorites) { product in
                        productRow(product)
                            .coachmarkTargetIf(product.id == favorites.first?.id, .libraryFavorites)
                    }
                } header: {
                    SectionLabel(text: "Favoriten")
                        .padding(.top, 4)
                }
                .listRowBackground(Color.cardBackground)
                .listRowSeparatorTint(Color.inkDivider)
            }

            Section {
                if coachmarkDemo {
                    // Demo-Items mit Mix aus 3 source-Tags (OCR / Manuell / Gericht)
                    ForEach(CoachmarkDemoData.demoMyProducts) { demo in
                        demoMyProductRow(demo)
                    }
                } else if myProducts.isEmpty {
                    HStack {
                        MascotView(size: 24, mood: .think, tone: .beige)
                        Text("Noch keine gescannten oder manuellen Produkte.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .padding(.vertical, 8)
                    // Fallback: wenn weder Favoriten noch Meine Produkte → Section-Header
                    // ist das einzige Spotlight-Target
                    .coachmarkTargetIf(favorites.isEmpty, .libraryFavorites)
                } else {
                    ForEach(myProducts) { product in
                        productRow(product)
                            // Fallback: wenn keine Favoriten existieren, erste Meine-Produkte-Row
                            // markieren
                            .coachmarkTargetIf(
                                favorites.isEmpty && product.id == myProducts.first?.id,
                                .libraryFavorites
                            )
                    }
                    .onDelete { indexSet in
                        for i in indexSet { modelContext.delete(myProducts[i]) }
                        modelContext.saveOrLog("LibraryView: Produkt gelöscht")
                    }
                }
            } header: {
                SectionLabel(text: "Meine Produkte")
                    .padding(.top, 4)
            }
            .listRowBackground(Color.cardBackground)
            .listRowSeparatorTint(Color.inkDivider)

            // BLV-/Preloaded-Treffer — nur wenn aktiv gesucht und Treffer vorhanden
            if !blvSearchResults.isEmpty {
                Section {
                    ForEach(blvSearchResults) { product in
                        productRow(product)
                    }
                } header: {
                    SectionLabel(text: "Schweizer Datenbank")
                        .padding(.top, 4)
                }
                .listRowBackground(Color.cardBackground)
                .listRowSeparatorTint(Color.inkDivider)
            }

            // Keine-Treffer-Hinweis (nur bei aktiver Suche, wenn nichts gefunden)
            if hasNoResults {
                Section {
                    VStack(spacing: 10) {
                        MascotView(size: 56, mood: .think, tone: .beige)
                            .padding(.top, 8)
                        Text("Keine Treffer für „\(searchText)\"")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("Versuch eine andere Schreibweise — oder leg das Produkt manuell an.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // Bottom padding für FloatingTabBar (sonst wird die letzte Row verdeckt)
            Section {
                Color.clear
                    .frame(height: 90)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Product Row

    private func productRow(_ product: Product) -> some View {
        HStack(spacing: 12) {
            // Letter avatar (tapping opens detail; the star button handles its own tap)
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
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(product.isFavorite ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen")
            .accessibilityValue(product.name)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { selectedProduct = product }
    }

    // MARK: - Demo Favorite Row (Coachmark-Tour)

    private func demoFavoriteRow(_ fav: CoachmarkDemoData.DemoFavorite) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.terra.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(String(fav.name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.warmBrown)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(fav.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text("\(fav.kcalPer100g) kcal · \(fav.proteinPer100g, specifier: "%.1f")g P")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer()
            Image(systemName: "star.fill")
                .foregroundStyle(Color.amber)
                .font(.system(size: 16))
        }
        .padding(.vertical, 4)
    }

    private func demoMyProductRow(_ demo: CoachmarkDemoData.DemoMyProduct) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.terra.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(String(demo.name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.warmBrown)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(demo.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                HStack(spacing: 6) {
                    Text("\(demo.kcalPer100g) kcal · \(demo.proteinPer100g, specifier: "%.1f")g P")
                        .foregroundStyle(Color.inkSecondary)
                    demoSourceTag(for: demo.source)
                }
                .font(.system(size: 11))
            }
            Spacer()
            Image(systemName: "star")
                .foregroundStyle(Color.inkTertiary)
                .font(.system(size: 16))
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func demoSourceTag(for source: ProductSource) -> some View {
        switch source {
        case .ocr:    Text("· Gescannt").foregroundStyle(Color.terra)
        case .dish:   Text("· Gericht").foregroundStyle(Color.forest)
        case .manual: Text("· Manuell").foregroundStyle(Color.warmBrown)
        default:      EmptyView()
        }
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
        case .barcode:
            Text("· Barcode").foregroundStyle(Color.terra)
        default:
            EmptyView()
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: Product.self, inMemory: true)
}
