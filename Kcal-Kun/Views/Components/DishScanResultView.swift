import SwiftUI
import SwiftData

struct DishScanResultView: View {
    @Bindable var vm: DishScannerViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var selectedSlot: MealSlot = .lunch
    @State private var gramsText = ""

    private var canAdd: Bool { !vm.dishName.isEmpty && vm.grams > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        mascotHeader

                        // Dish name card
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Gericht")
                            HStack {
                                TextField("Name", text: $vm.dishName)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.inkPrimary)
                            }
                            .padding(14)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
                        }

                        // Portion card
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Portion")
                            HStack {
                                TextField("Gramm", text: $gramsText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.inkPrimary)
                                    .onChange(of: gramsText) {
                                        if let v = Double(gramsText.replacingOccurrences(of: ",", with: ".")) {
                                            vm.grams = v
                                        }
                                    }
                                Text("g")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.inkSecondary)
                            }
                            .padding(14)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
                        }

                        // Nutrition card
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Nährwerte (geschätzt)")
                            VStack(spacing: 0) {
                                macroRow("Energie",       value: vm.kcalTotal,    unit: "kcal", color: Color.terra)
                                Divider().padding(.leading, 14)
                                macroRow("Protein",       value: vm.proteinTotal, unit: "g",    color: Color.terra)
                                Divider().padding(.leading, 14)
                                macroRow("Fett",          value: vm.fatTotal,     unit: "g",    color: Color.amber)
                                Divider().padding(.leading, 14)
                                macroRow("Kohlenhydrate", value: vm.carbsTotal,   unit: "g",    color: Color.forest)
                                Divider().padding(.leading, 14)
                                macroRow("Ballaststoffe", value: vm.fiberTotal,   unit: "g",    color: Color.inkSecondary)
                            }
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
                        }

                        // Diary settings card
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Tagebuch")
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Datum")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.inkSecondary)
                                    Spacer()
                                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(Color.terra)
                                        .environment(\.locale, Locale(identifier: "de_CH"))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                Divider().padding(.leading, 14)
                                HStack {
                                    Text("Mahlzeit")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.inkSecondary)
                                    Spacer()
                                    Picker("", selection: $selectedSlot) {
                                        ForEach(MealSlot.allCases) { slot in
                                            Label(slot.rawValue, systemImage: slot.systemImage).tag(slot)
                                        }
                                    }
                                    .labelsHidden()
                                    .tint(Color.warmBrown)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
                        }

                        // Add button
                        Button {
                            addDishEntry()
                        } label: {
                            Label("Zum Tagebuch hinzufügen", systemImage: "plus.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canAdd ? Color.terra : Color.inkDivider)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .shadow(color: canAdd ? Color.terra.opacity(0.32) : .clear, radius: 18, x: 0, y: 8)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAdd)
                        .animation(.spring(response: 0.25), value: canAdd)

                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Gericht")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
            .onAppear {
                gramsText = vm.grams > 0 ? String(Int(vm.grams.rounded())) : ""
            }
        }
    }

    private var mascotHeader: some View {
        HStack(spacing: 14) {
            MascotView(size: 56, mood: .wow, tone: .cream)
            VStack(alignment: .leading, spacing: 2) {
                Text("Gericht analysiert!")
                    .font(.display(19))
                    .foregroundStyle(Color.inkPrimary)
                Text("Überprüfe die geschätzten Nährwerte.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color.beige, Color.cardBackground], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: 0x7C5E3C).opacity(0.10), lineWidth: 1))
    }

    private func macroRow(_ label: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            Text("\(Int(value.rounded())) \(unit)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func addDishEntry() {
        let product = Product(
            name:           vm.dishName,
            kcalPer100g:    vm.kcalPer100g,
            proteinPer100g: vm.proteinPer100g,
            fatPer100g:     vm.fatPer100g,
            carbsPer100g:   vm.carbsPer100g,
            fiberPer100g:   vm.fiberPer100g,
            source:         .dish
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
