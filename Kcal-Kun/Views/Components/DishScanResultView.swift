import SwiftUI
import SwiftData

struct DishScanResultView: View {
    @Bindable var vm: DishScannerViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var selectedSlot: MealSlot = .lunch
    @State private var gramsText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Gericht") {
                    TextField("Name", text: $vm.dishName)
                }

                Section("Portion") {
                    HStack {
                        TextField("Gramm", text: $gramsText)
                            .keyboardType(.decimalPad)
                            .onChange(of: gramsText) {
                                if let v = Double(gramsText.replacingOccurrences(of: ",", with: ".")) {
                                    vm.grams = v
                                }
                            }
                        Text("g")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Nährwerte (geschätzt)") {
                    macroRow("Energie",         value: vm.kcalTotal,    unit: "kcal")
                    macroRow("Protein",         value: vm.proteinTotal, unit: "g")
                    macroRow("Fett",            value: vm.fatTotal,     unit: "g")
                    macroRow("Kohlenhydrate",   value: vm.carbsTotal,   unit: "g")
                    macroRow("Ballaststoffe",   value: vm.fiberTotal,   unit: "g")
                }

                Section("Tagebuch") {
                    DatePicker("Datum", selection: $selectedDate, displayedComponents: .date)
                    Picker("Mahlzeit", selection: $selectedSlot) {
                        ForEach(MealSlot.allCases) { slot in
                            Label(slot.rawValue, systemImage: slot.systemImage).tag(slot)
                        }
                    }
                }

                Section {
                    Button {
                        addDishEntry()
                    } label: {
                        Label("Zum Tagebuch hinzufügen", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(vm.dishName.isEmpty || vm.grams <= 0)
                }
            }
            .navigationTitle("Gericht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onAppear {
                gramsText = vm.grams > 0 ? String(Int(vm.grams.rounded())) : ""
            }
        }
    }

    private func macroRow(_ label: String, value: Double, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Int(value.rounded())) \(unit)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func addDishEntry() {
        let product = Product(
            name:          vm.dishName,
            kcalPer100g:   vm.kcalPer100g,
            proteinPer100g: vm.proteinPer100g,
            fatPer100g:    vm.fatPer100g,
            carbsPer100g:  vm.carbsPer100g,
            fiberPer100g:  vm.fiberPer100g,
            source:        .dish
        )
        modelContext.insert(product)

        let entry = DiaryEntry(
            date:     selectedDate,
            mealSlot: selectedSlot,
            product:  product,
            grams:    vm.grams
        )
        modelContext.insert(entry)
        try? modelContext.save()

        vm.reset()
        dismiss()
    }
}
