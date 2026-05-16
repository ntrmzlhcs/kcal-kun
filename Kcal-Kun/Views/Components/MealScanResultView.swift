import SwiftUI
import SwiftData

struct MealScanResultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var vm: MealScannerViewModel

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var selectedSlot: MealSlot = .lunch

    private var canAdd: Bool {
        vm.components.contains { $0.isSelected && $0.matchedProduct != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        mascotHeader

                        // Ingredients card
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Erkannte Zutaten")
                            VStack(spacing: 0) {
                                ForEach($vm.components) { $component in
                                    ComponentRow(component: $component)
                                    if component.id != vm.components.last?.id {
                                        Divider().padding(.leading, 14)
                                    }
                                }
                            }
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))

                            Text("Einträge ohne Datenbank-Treffer werden übersprungen.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.inkTertiary)
                                .padding(.horizontal, 4)
                        }

                        // Meal settings card
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Mahlzeit")
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Datum")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.inkSecondary)
                                    Spacer()
                                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(Color.terra)
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
                            addEntries()
                        } label: {
                            Text("Hinzufügen")
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
                    Text("Mahlzeit analysiert")
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

    private var mascotHeader: some View {
        HStack(spacing: 14) {
            MascotView(size: 56, mood: .wow, tone: .cream)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mahlzeit erkannt!")
                    .font(.display(19))
                    .foregroundStyle(Color.inkPrimary)
                Text("Wähle die Zutaten, die du tracken möchtest.")
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
            Button {
                component.isSelected.toggle()
            } label: {
                Image(systemName: component.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(component.isSelected ? (hasMatch ? Color.forest : Color.amber) : Color.inkTertiary)
                    .font(.system(size: 20))
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 2) {
                Text(component.blvName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(hasMatch ? Color.inkPrimary : Color.inkSecondary)
                if !hasMatch {
                    Text("Nicht in Datenbank")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.amber)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                TextField("g", text: $gramsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.terra)
                    .onChange(of: gramsText) { _, new in
                        if let g = Double(new.replacingOccurrences(of: ",", with: ".")) {
                            component.grams = g
                        }
                    }
                Text("g")
                    .foregroundStyle(Color.inkSecondary)
                    .font(.system(size: 13))
            }

            if let kcal = kcalPreview {
                Text("\(kcal)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.terra)
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .onAppear {
            gramsText = component.grams.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(component.grams))
                : String(format: "%.0f", component.grams)
        }
    }
}
