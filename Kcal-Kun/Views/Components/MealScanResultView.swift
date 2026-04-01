import SwiftUI
import SwiftData

struct MealScanResultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var vm: MealScannerViewModel

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var selectedSlot: MealSlot = .lunch

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($vm.components) { $component in
                        ComponentRow(component: $component)
                    }
                } header: {
                    Text("Erkannte Zutaten")
                } footer: {
                    Text("Einträge ohne Datenbank-Treffer werden übersprungen.")
                        .font(.caption)
                }

                Section("Mahlzeit") {
                    DatePicker("Datum", selection: $selectedDate, displayedComponents: .date)
                    Picker("Slot", selection: $selectedSlot) {
                        ForEach(MealSlot.allCases) { slot in
                            Label(slot.rawValue, systemImage: slot.systemImage).tag(slot)
                        }
                    }
                }
            }
            .navigationTitle("Mahlzeit analysiert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { addEntries() }
                        .disabled(!vm.components.contains { $0.isSelected && $0.matchedProduct != nil })
                }
            }
        }
    }

    private func addEntries() {
        for component in vm.components where component.isSelected {
            guard let product = component.matchedProduct else { continue }
            let entry = DiaryEntry(
                date: selectedDate,
                mealSlot: selectedSlot,
                product: product,
                grams: component.grams
            )
            modelContext.insert(entry)
        }
        try? modelContext.save()
        vm.reset()
        dismiss()
    }
}

private struct ComponentRow: View {
    @Binding var component: MealComponent

    @State private var gramsText: String = ""

    private var hasMatch: Bool { component.matchedProduct != nil }

    private var kcalPreview: Int? {
        guard let product = component.matchedProduct,
              let g = Double(gramsText.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return Int((product.kcalPer100g * g / 100).rounded())
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: component.isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(component.isSelected ? (hasMatch ? .green : .orange) : .secondary)
                .font(.title3)
                .onTapGesture { component.isSelected.toggle() }

            VStack(alignment: .leading, spacing: 2) {
                Text(component.blvName)
                    .font(.subheadline)
                    .foregroundStyle(hasMatch ? .primary : .secondary)
                if !hasMatch {
                    Text("Nicht in Datenbank")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                TextField("g", text: $gramsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52)
                    .onChange(of: gramsText) { _, new in
                        if let g = Double(new.replacingOccurrences(of: ",", with: ".")) {
                            component.grams = g
                        }
                    }
                Text("g")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            if let kcal = kcalPreview {
                Text("\(kcal) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .onAppear {
            gramsText = component.grams.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(component.grams))
                : String(format: "%.0f", component.grams)
        }
    }
}
