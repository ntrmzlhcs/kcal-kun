import SwiftUI
import SwiftData

struct ProductDetailView: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false

    private var isDeletable: Bool {
        product.source == .ocr || product.source == .manual || product.source == .dish || product.source == .barcode
    }

    private var sourceBadgeLabel: String {
        switch product.source {
        case .ocr:              "Gescannt"
        case .manual:           "Manuell"
        case .dish:             "Gericht-Analyse"
        case .preloaded, .blvApi: "BLV-Datenbank"
        case .meal:             "Lebensmittel"
        case .barcode:          "Open Food Facts"
        }
    }

    private var sourceBadgeIcon: String {
        switch product.source {
        case .ocr:              "camera.fill"
        case .manual:           "pencil"
        case .dish:             "frying.pan"
        case .preloaded, .blvApi: "books.vertical.fill"
        case .meal:             "list.bullet"
        case .barcode:          "barcode.viewfinder"
        }
    }

    private var createdLabel: String {
        product.createdAt.formatted(
            .dateTime.day().month(.wide).year()
                .locale(Locale(identifier: "de_CH"))
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerCard
                        kcalCard
                        macroCard
                        verlaufCard
                        if isDeletable {
                            deleteButton
                        }
                        Spacer().frame(height: 70)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Produkt")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.inkSecondary)
                            .font(.system(size: 22))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Schliessen")
                }
                if isDeletable {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Bearbeiten") { showEditSheet = true }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.warmBrown)
                    }
                }
            }
            .confirmationDialog(
                "Produkt löschen?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) {
                    modelContext.delete(product)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Das Produkt wird aus der Bibliothek entfernt. Tagebucheinträge bleiben erhalten.")
            }
            .sheet(isPresented: $showEditSheet) {
                ManualProductEntryView(editingProduct: product)
            }
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(sourceBadgeLabel, systemImage: sourceBadgeIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.warmBrown)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: 0x7C5E3C).opacity(0.10))
                    .clipShape(Capsule())
                Spacer()
                Button {
                    product.isFavorite.toggle()
                } label: {
                    Image(systemName: product.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundStyle(product.isFavorite ? Color.amber : Color.inkSecondary)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(product.isFavorite ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen")
            }

            Text(product.name)
                .font(.display(32))
                .foregroundStyle(Color.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let brand = product.brand, !brand.isEmpty {
                Text(brand)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(18)
        .heroCardStyle()
    }

    private var kcalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "pro 100 g")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(product.kcalPer100g.rounded()))")
                    .font(.display(48))
                    .foregroundStyle(Color.inkPrimary)
                    .monospacedDigit()
                Text("kcal")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .heroCardStyle()
    }

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Nährwerte pro 100 g")

            HStack(spacing: 0) {
                macroColumn("Protein",       value: product.proteinPer100g, color: .terra)
                Divider().frame(height: 40).overlay(Color.inkDivider)
                macroColumn("Fett",          value: product.fatPer100g,     color: .amber)
                Divider().frame(height: 40).overlay(Color.inkDivider)
                macroColumn("Kohlenhydrate", value: product.carbsPer100g,   color: .forest)
            }

            let hasSecondary = product.fiberPer100g != nil
                || product.sugarPer100g != nil
                || product.saltPer100g  != nil
            if hasSecondary {
                Divider().overlay(Color.inkDivider)
                VStack(spacing: 8) {
                    if let fiber = product.fiberPer100g {
                        macroRow("Ballaststoffe", value: fiber)
                    }
                    if let sugar = product.sugarPer100g {
                        macroRow("davon Zucker", value: sugar)
                    }
                    if let salt = product.saltPer100g {
                        macroRow("Salz", value: salt)
                    }
                }
            }

            if let serving = product.servingSizeGrams {
                Divider().overlay(Color.inkDivider)
                HStack {
                    Text("Portionsgrösse")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                    Text("\(Int(serving)) g")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                }
            }
        }
        .padding(18)
        .heroCardStyle()
    }

    private var verlaufCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Verlauf")
            verlaufRow(icon: "calendar",      label: "Erstellt am",  value: createdLabel)
            Divider().overlay(Color.inkDivider)
            verlaufRow(icon: "book.closed",   label: "Im Tagebuch",  value: "\(product.entries.count)× verwendet")
            Divider().overlay(Color.inkDivider)
            verlaufRow(icon: sourceBadgeIcon, label: "Quelle",       value: sourceBadgeLabel)
        }
        .padding(18)
        .heroCardStyle()
    }

    private var deleteButton: some View {
        Button { showDeleteConfirmation = true } label: {
            Label("Produkt löschen", systemImage: "trash")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color.terra)
                .background(Color.terra.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.terra.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func macroColumn(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(formatG(value))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .monospacedDigit()
            Text("g")
                .font(.system(size: 11))
                .foregroundStyle(Color.inkSecondary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func macroRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            Text("\(formatG(value)) g")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
        }
    }

    private func verlaufRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.warmBrown)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
        }
    }

    private func formatG(_ v: Double) -> String {
        v < 10 ? String(format: "%.1f", v) : "\(Int(v.rounded()))"
    }
}
