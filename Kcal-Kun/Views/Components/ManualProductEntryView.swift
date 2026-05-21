import SwiftUI
import SwiftData

struct ManualProductEntryView: View {
    let editingProduct: Product?
    /// Optional: EAN-Code, falls die Manuelle Eingabe aus dem Barcode-Not-Found-
    /// Flow kommt. Wird beim Speichern auf das Product persistiert, sodass
    /// derselbe Scan beim nächsten Mal lokal getroffen wird.
    let prefilledBarcode: String?

    init(editingProduct: Product? = nil, prefilledBarcode: String? = nil) {
        self.editingProduct = editingProduct
        self.prefilledBarcode = prefilledBarcode
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""
    @State private var fiber = ""
    @State private var sugar = ""
    @State private var salt = ""
    @State private var showOptional = false
    @FocusState private var nameFocused: Bool

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
                    VStack(spacing: 16) {
                        // Product name
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Produkt")
                            HStack {
                                TextField("Name (Pflichtfeld)", text: $name)
                                    .focused($nameFocused)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.inkPrimary)
                            }
                            .padding(14)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
                        }

                        // Core nutrition
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

                        // Optional nutrition
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

                        // Save button
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
                        .animation(.spring(response: 0.25), value: canSave)

                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(editingProduct == nil ? "Produkt erfassen" : "Produkt bearbeiten")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
            .onAppear {
                if let p = editingProduct {
                    name    = p.name
                    kcal    = formatForField(p.kcalPer100g)
                    protein = formatForField(p.proteinPer100g)
                    fat     = formatForField(p.fatPer100g)
                    carbs   = formatForField(p.carbsPer100g)
                    fiber   = p.fiberPer100g.map { formatForField($0) } ?? ""
                    sugar   = p.sugarPer100g.map { formatForField($0) } ?? ""
                    salt    = p.saltPer100g.map  { formatForField($0) } ?? ""
                    if fiber != "" || sugar != "" || salt != "" { showOptional = true }
                } else {
                    nameFocused = true
                }
            }
        }
    }

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
        guard let kcalVal    = parseDouble(kcal),
              let proteinVal = parseDouble(protein),
              let fatVal     = parseDouble(fat),
              let carbsVal   = parseDouble(carbs) else { return }

        if let p = editingProduct {
            p.name           = name.trimmingCharacters(in: .whitespaces)
            p.kcalPer100g    = kcalVal
            p.proteinPer100g = proteinVal
            p.fatPer100g     = fatVal
            p.carbsPer100g   = carbsVal
            p.fiberPer100g   = parseDouble(fiber)
            p.sugarPer100g   = parseDouble(sugar)
            p.saltPer100g    = parseDouble(salt)
        } else {
            let product = Product(
                name: name.trimmingCharacters(in: .whitespaces),
                kcalPer100g: kcalVal,
                proteinPer100g: proteinVal,
                fatPer100g: fatVal,
                carbsPer100g: carbsVal,
                fiberPer100g: parseDouble(fiber),
                sugarPer100g: parseDouble(sugar),
                saltPer100g: parseDouble(salt),
                source: .manual,
                barcode: prefilledBarcode
            )
            modelContext.insert(product)
        }
        try? modelContext.save()
        dismiss()
    }

    private func formatForField(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

private func parseDouble(_ text: String) -> Double? {
    let normalized = text.replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
}
