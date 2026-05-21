import SwiftUI
import SwiftData

struct ScanConfirmationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vm: ScannerViewModel
    let initialResult: NutritionScanResult
    /// Optional: EAN-Code, falls dieser OCR-Save aus dem Barcode-Not-Found-Flow
    /// kommt. Wird beim Speichern auf das Product persistiert, sodass derselbe
    /// Scan beim nächsten Mal lokal getroffen wird.
    let prefilledBarcode: String?

    @State private var name: String
    @State private var kcal: String
    @State private var protein: String
    @State private var fat: String
    @State private var carbs: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var salt: String
    @State private var showOptional = false

    init(vm: ScannerViewModel, result: NutritionScanResult, prefilledBarcode: String? = nil) {
        self.vm = vm
        self.initialResult = result
        self.prefilledBarcode = prefilledBarcode
        _name = State(initialValue: result.productNameGuess ?? "")
        _kcal = State(initialValue: result.kcalPer100g.map { formatDouble($0) } ?? "")
        _protein = State(initialValue: result.proteinPer100g.map { formatDouble($0) } ?? "")
        _fat = State(initialValue: result.fatPer100g.map { formatDouble($0) } ?? "")
        _carbs = State(initialValue: result.carbsPer100g.map { formatDouble($0) } ?? "")
        _fiber = State(initialValue: result.fiberPer100g.map { formatDouble($0) } ?? "")
        _sugar = State(initialValue: result.sugarPer100g.map { formatDouble($0) } ?? "")
        _salt = State(initialValue: result.saltPer100g.map { formatDouble($0) } ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        parseDouble(kcal) != nil &&
        parseDouble(protein) != nil &&
        parseDouble(fat) != nil &&
        parseDouble(carbs) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        mascotHeader
                        formContent
                        saveButton
                        Spacer().frame(height: 24)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Produkt speichern")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
        }
    }

    // MARK: - Mascot Header

    private var mascotHeader: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                MascotView(size: 90, mood: .smug, tone: .cream, tilt: -4)
                Text("Gefunden")
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

            Text("Überprüfe die Nährwerte und speichere das Produkt.")
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Form Content

    private var formContent: some View {
        VStack(spacing: 14) {
            // Product name card
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Produkt")
                VStack(spacing: 0) {
                    HStack {
                        TextField("Name (Pflichtfeld)", text: $name)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .padding(14)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
                }
            }

            // Core nutrition card
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Nährwerte pro 100 g")
                VStack(spacing: 0) {
                    nutritionRow("Kalorien (kcal)", value: $kcal, required: true, isLast: false)
                    Divider().padding(.leading, 14)
                    nutritionRow("Protein (g)", value: $protein, required: true, isLast: false)
                    Divider().padding(.leading, 14)
                    nutritionRow("Fett (g)", value: $fat, required: true, isLast: false)
                    Divider().padding(.leading, 14)
                    nutritionRow("Kohlenhydrate (g)", value: $carbs, required: true, isLast: true)
                }
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
            }

            // Optional nutrition card
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
                        nutritionRow("Ballaststoffe (g)", value: $fiber, required: false, isLast: false)
                        Divider().padding(.leading, 14)
                        nutritionRow("Zucker (g)", value: $sugar, required: false, isLast: false)
                        Divider().padding(.leading, 14)
                        nutritionRow("Salz (g)", value: $salt, required: false, isLast: true)
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

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveAndDismiss()
        } label: {
            Text("Speichern")
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

    // MARK: - Nutrition Row

    @ViewBuilder
    private func nutritionRow(_ label: String, value: Binding<String>, required: Bool, isLast: Bool) -> some View {
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
                    required && parseDouble(value.wrappedValue) == nil && !value.wrappedValue.isEmpty
                    ? Color.red
                    : Color.terra
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func saveAndDismiss() {
        var result = initialResult
        result.kcalPer100g = parseDouble(kcal)
        result.proteinPer100g = parseDouble(protein)
        result.fatPer100g = parseDouble(fat)
        result.carbsPer100g = parseDouble(carbs)
        result.fiberPer100g = parseDouble(fiber)
        result.sugarPer100g = parseDouble(sugar)
        result.saltPer100g = parseDouble(salt)

        vm.saveProduct(
            name: name.trimmingCharacters(in: .whitespaces),
            result: result,
            context: modelContext,
            barcode: prefilledBarcode
        )
        dismiss()
    }
}

private func formatDouble(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0
        ? String(Int(value))
        : String(format: "%.1f", value)
}

private func parseDouble(_ text: String) -> Double? {
    let normalized = text.replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
}
