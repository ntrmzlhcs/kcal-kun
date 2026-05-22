import SwiftUI
import SwiftData

struct BackupExportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var fileURL: URL?
    @State private var error: String?
    @State private var productCount = 0
    @State private var entryCount = 0
    @State private var isPreparing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        MascotView(size: 96, mood: .happy, tone: .cream)
                            .padding(.top, 12)

                        Text("Backup exportieren")
                            .font(.display(28))
                            .foregroundStyle(Color.inkPrimary)

                        Text("Alle Tagebuch-Einträge, eigene Produkte und dein Profil werden in einer einzelnen Datei gesichert. Speichere sie in iCloud Drive, schick sie dir per Mail oder per AirDrop auf den Mac.")
                            .font(.callout)
                            .foregroundStyle(Color.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .fixedSize(horizontal: false, vertical: true)

                        infoCard

                        encryptionWarningCard

                        if let url = fileURL {
                            ShareLink(item: url,
                                      preview: SharePreview(url.lastPathComponent,
                                                            image: Image(systemName: "doc.text"))) {
                                primaryLabel("Datei teilen", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 28)

                            Text(url.lastPathComponent)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.inkTertiary)
                                .padding(.top, -8)
                        } else {
                            Button { prepare() } label: {
                                if isPreparing {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.terra)
                                        .clipShape(Capsule())
                                } else {
                                    primaryLabel("Backup erstellen", systemImage: "shield.lefthalf.filled")
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 28)
                            .disabled(isPreparing)
                        }

                        if let error {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }

                        Spacer().frame(height: 24)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Daten sichern")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
            .onAppear { loadCounts() }
        }
    }

    // MARK: - Subviews

    /// DSGVO-Hinweis: das exportierte JSON enthält Gesundheitsdaten (Tagebuch,
    /// Gewicht, KI-Analysen) im Klartext. Der User soll bewusst entscheiden,
    /// wo er die Datei ablegt.
    private var encryptionWarningCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.amber)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("Backup ist unverschlüsselt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.warmBrown)
                Text("Die Datei enthält Tagebuch, Gewicht und Profil im Klartext. Speichere sie nur an sicheren Orten (iCloud Drive ist OK, öffentliche Cloud-Dienste oder unverschlüsselte Mail-Anhänge nicht).")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.amber.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.amber.opacity(0.30), lineWidth: 1))
        .padding(.horizontal, 28)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            infoRow(icon: "person.text.rectangle", label: "Profil",            value: "1 Eintrag")
            Divider().overlay(Color.inkDivider)
            infoRow(icon: "tag",                   label: "Eigene Produkte",  value: "\(productCount)")
            Divider().overlay(Color.inkDivider)
            infoRow(icon: "book.closed",           label: "Tagebuch-Einträge", value: "\(entryCount)")
        }
        .padding(16)
        .heroCardStyle()
        .padding(.horizontal, 28)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
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

    private func primaryLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.terra)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: Color.terra.opacity(0.32), radius: 18, x: 0, y: 8)
    }

    // MARK: - Logik

    private func loadCounts() {
        do {
            let products = try context.fetch(FetchDescriptor<Product>())
            productCount = products.filter {
                $0.source == .ocr || $0.source == .manual || $0.source == .dish || $0.source == .barcode
            }.count
            entryCount = try context.fetch(FetchDescriptor<DiaryEntry>()).count
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func prepare() {
        isPreparing = true
        error = nil
        do {
            let data = try BackupService.export(context: context)
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(BackupService.suggestedFileName())
            try data.write(to: tmp, options: .atomic)
            fileURL = tmp
        } catch {
            self.error = error.localizedDescription
        }
        isPreparing = false
    }
}
