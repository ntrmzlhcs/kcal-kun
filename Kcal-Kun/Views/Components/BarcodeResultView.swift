import SwiftUI
import SwiftData

/// Preview-Sheet nach erfolgreichem OFF-Lookup oder lokalem Bibliotheks-Treffer.
/// Zeigt die Nährwerte editierbar an und bietet je nach Aufruf-Kontext
/// unterschiedliche Save-Aktionen:
/// - **ScannerTab**: nur "Zur Bibliothek hinzufügen"
/// - **QuickAdd**:   Gramm-Eingabe + "Loggen" → Product + DiaryEntry
struct BarcodeResultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let result: OFFNutrientResult?
    let localMatch: Product?
    let context: BarcodeScanContext

    @State private var name: String
    @State private var brand: String
    @State private var kcal: String
    @State private var protein: String
    @State private var fat: String
    @State private var carbs: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var salt: String
    @State private var gramsText: String = ""
    @State private var showOptional = false
    @State private var showLicenseInfo = false
    @FocusState private var gramsFocused: Bool

    init(result: OFFNutrientResult?, localMatch: Product?, context: BarcodeScanContext) {
        self.result = result
        self.localMatch = localMatch
        self.context = context

        // Pre-fill aus OFF-Result oder aus lokalem Treffer
        if let r = result {
            _name    = State(initialValue: r.name)
            _brand   = State(initialValue: r.brand ?? "")
            _kcal    = State(initialValue: bcFormat(r.kcalPer100g))
            _protein = State(initialValue: bcFormat(r.proteinPer100g))
            _fat     = State(initialValue: bcFormat(r.fatPer100g))
            _carbs   = State(initialValue: bcFormat(r.carbsPer100g))
            _fiber   = State(initialValue: r.fiberPer100g.map { bcFormat($0) } ?? "")
            _sugar   = State(initialValue: r.sugarPer100g.map { bcFormat($0) } ?? "")
            _salt    = State(initialValue: r.saltPer100g.map { bcFormat($0) } ?? "")
            // Wenn OFF eine sinnvolle Portion liefert, als Default ins Grams-Feld
            if let s = r.servingSizeGrams, s > 0 {
                _gramsText = State(initialValue: bcFormat(s))
            }
        } else if let p = localMatch {
            _name    = State(initialValue: p.name)
            _brand   = State(initialValue: p.brand ?? "")
            _kcal    = State(initialValue: bcFormat(p.kcalPer100g))
            _protein = State(initialValue: bcFormat(p.proteinPer100g))
            _fat     = State(initialValue: bcFormat(p.fatPer100g))
            _carbs   = State(initialValue: bcFormat(p.carbsPer100g))
            _fiber   = State(initialValue: p.fiberPer100g.map { bcFormat($0) } ?? "")
            _sugar   = State(initialValue: p.sugarPer100g.map { bcFormat($0) } ?? "")
            _salt    = State(initialValue: p.saltPer100g.map { bcFormat($0) } ?? "")
            if let s = p.servingSizeGrams, s > 0 {
                _gramsText = State(initialValue: bcFormat(s))
            }
        } else {
            _name = State(initialValue: "")
            _brand = State(initialValue: "")
            _kcal = State(initialValue: "")
            _protein = State(initialValue: "")
            _fat = State(initialValue: "")
            _carbs = State(initialValue: "")
            _fiber = State(initialValue: "")
            _sugar = State(initialValue: "")
            _salt = State(initialValue: "")
        }
    }

    private var isQuickAdd: Bool {
        if case .quickAdd = context { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        bcParse(kcal) != nil &&
        bcParse(protein) != nil &&
        bcParse(fat) != nil &&
        bcParse(carbs) != nil &&
        (!isQuickAdd || (bcParse(gramsText) ?? 0) > 0)
    }

    private var currentBarcode: String? {
        result?.barcode ?? localMatch?.barcode
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        mascotHeader
                        formContent
                        if isQuickAdd { gramsCard }
                        saveButton
                        Spacer().frame(height: 24)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isQuickAdd ? "Eintrag prüfen" : "Produkt prüfen")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
            .alert("Open Food Facts", isPresented: $showLicenseInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Diese Nährwerte stammen aus der offenen Datenbank von Open Food Facts (ODbL-Lizenz). Die Daten sind crowd-sourced — bitte vor dem Speichern prüfen.")
            }
        }
    }

    // MARK: - Mascot Header

    private var mascotHeader: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                MascotView(size: 90, mood: .smug, tone: .cream, tilt: -4)
                Text(localMatch != nil ? "In Bibliothek" : "Gefunden")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.forest)
                    .clipShape(Capsule())
                    .offset(x: 8, y: -4)
            }

            if !name.isEmpty {
                Text(name)
                    .font(.display(22))
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Source-Badge — Tap zeigt Lizenz-Info
            if localMatch == nil {
                Button {
                    showLicenseInfo = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10))
                        Text("Open Food Facts")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.warmBrown)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.beige.opacity(0.5))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("Schon in deiner Bibliothek")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.forest)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.forest.opacity(0.1))
                .clipShape(Capsule())
            }

            Text(isQuickAdd
                 ? "Überprüfe die Nährwerte und logge zur Mahlzeit."
                 : "Überprüfe die Nährwerte und speichere das Produkt.")
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Produkt")
                VStack(spacing: 0) {
                    bcFormRow(label: "Name", text: $name, placeholder: "Pflichtfeld")
                    Divider().padding(.leading, 14)
                    bcFormRow(label: "Marke", text: $brand, placeholder: "optional")
                }
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Nährwerte pro 100 g")
                VStack(spacing: 0) {
                    bcNutritionRow("Kalorien (kcal)", value: $kcal, required: true)
                    Divider().padding(.leading, 14)
                    bcNutritionRow("Protein (g)", value: $protein, required: true)
                    Divider().padding(.leading, 14)
                    bcNutritionRow("Fett (g)", value: $fat, required: true)
                    Divider().padding(.leading, 14)
                    bcNutritionRow("Kohlenhydrate (g)", value: $carbs, required: true)
                }
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3)) { showOptional.toggle() }
                } label: {
                    HStack {
                        SectionLabel(text: "Weitere Nährwerte")
                        Spacer()
                        Image(systemName: showOptional ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.inkTertiary)
                    }
                }
                .buttonStyle(.plain)

                if showOptional {
                    VStack(spacing: 0) {
                        bcNutritionRow("Ballaststoffe (g)", value: $fiber, required: false)
                        Divider().padding(.leading, 14)
                        bcNutritionRow("Zucker (g)", value: $sugar, required: false)
                        Divider().padding(.leading, 14)
                        bcNutritionRow("Salz (g)", value: $salt, required: false)
                    }
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Grams Card (nur QuickAdd)

    private var gramsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Menge")
            HStack {
                TextField("Gramm", text: $gramsText)
                    .keyboardType(.decimalPad)
                    .focused($gramsFocused)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.terra)
                Text("g")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveAndDismiss()
        } label: {
            Text(isQuickAdd ? "Zum Tagebuch loggen" : "Zur Bibliothek hinzufügen")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Color.terra : Color.inkDivider)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .shadow(color: canSave ? Color.terra.opacity(0.32) : .clear, radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, 18)
        .animation(.spring(response: 0.25), value: canSave)
    }

    // MARK: - Generic Rows

    @ViewBuilder
    private func bcFormRow(label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func bcNutritionRow(_ label: String, value: Binding<String>, required: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            TextField(required ? "Pflichtfeld" : "optional", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    required && bcParse(value.wrappedValue) == nil && !value.wrappedValue.isEmpty
                    ? Color.red
                    : Color.terra
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Save Logic

    private func saveAndDismiss() {
        guard let kcalVal    = bcParse(kcal),
              let proteinVal = bcParse(protein),
              let fatVal     = bcParse(fat),
              let carbsVal   = bcParse(carbs) else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespaces)

        // Wenn wir auf einem lokalen Match sitzen, modifizieren wir bewusst NICHT —
        // der User soll bestehende Produkte über das normale Edit-UI ändern, nicht
        // durch versehentliche Re-Scans.
        let product: Product
        if let existing = localMatch {
            // Beim QuickAdd nutzen wir das bestehende Product direkt.
            product = existing
        } else {
            product = Product(
                name: trimmedName,
                brand: trimmedBrand.isEmpty ? nil : trimmedBrand,
                kcalPer100g: kcalVal,
                proteinPer100g: proteinVal,
                fatPer100g: fatVal,
                carbsPer100g: carbsVal,
                fiberPer100g: bcParse(fiber),
                sugarPer100g: bcParse(sugar),
                saltPer100g: bcParse(salt),
                servingSizeGrams: result?.servingSizeGrams,
                source: .barcode,
                barcode: currentBarcode
            )
            modelContext.insert(product)
        }

        // QuickAdd → DiaryEntry erstellen
        if case .quickAdd(let date, let slot) = context, let grams = bcParse(gramsText), grams > 0 {
            let entry = DiaryEntry(
                date: date,
                mealSlot: slot,
                product: product,
                grams: grams
            )
            modelContext.insert(entry)
        }

        modelContext.saveOrLog("BarcodeResult: Produkt/Eintrag gespeichert")
        dismiss()
    }
}

// MARK: - Format Helpers (file-scoped, eindeutige Namen um nicht mit anderen
// Files zu kollidieren — Swift erlaubt mehrere `formatDouble` in unterschiedlichen
// Files nur, wenn sie privat sind, aber zur Sicherheit haben wir hier ein
// `bc`-Präfix).

private func bcFormat(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0
        ? String(Int(value))
        : String(format: "%.1f", value)
}

private func bcParse(_ text: String) -> Double? {
    let normalized = text.replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
}
