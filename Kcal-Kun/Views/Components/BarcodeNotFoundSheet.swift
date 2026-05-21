import SwiftUI

/// Wird gezeigt, wenn ein gescannter EAN in Open Food Facts nicht existiert.
/// Bietet zwei Fallback-Pfade: OCR-Etikett-Scan oder manuelle Eingabe.
/// Der scanned `barcode` wird an den jeweiligen Save-Pfad durchgereicht, sodass
/// der Code beim Save auf das Product persistiert wird.
struct BarcodeNotFoundSheet: View {
    @Environment(\.dismiss) private var dismiss

    let barcode: String
    let onLabelScan: () -> Void   // OCR-Flow öffnen
    let onManualEntry: () -> Void // Manuelle Eingabe öffnen

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        mascotHeader

                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Gescannter Code")
                            HStack {
                                Image(systemName: "barcode")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.warmBrown)
                                Text(barcode)
                                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.inkPrimary)
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
                        }
                        .padding(.horizontal, 18)

                        VStack(spacing: 10) {
                            Button {
                                onLabelScan()
                            } label: {
                                Label("Etikett scannen", systemImage: "doc.text.viewfinder")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.terra)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.terra.opacity(0.32), radius: 14, x: 0, y: 6)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onManualEntry()
                            } label: {
                                Label("Manuell eingeben", systemImage: "pencil")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.cardBackground)
                                    .foregroundStyle(Color.warmBrown)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.warmBrown.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 18)

                        Spacer().frame(height: 24)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Code nicht gefunden")
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
        VStack(spacing: 10) {
            MascotView(size: 90, mood: .think, tone: .cream, tilt: 4)
            Text("Hmm, keinen Treffer …")
                .font(.display(22))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Text("Diesen Code hat Open Food Facts nicht. Wie möchtest du das Produkt erfassen?")
                .font(.system(size: 13))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 12)
    }
}
