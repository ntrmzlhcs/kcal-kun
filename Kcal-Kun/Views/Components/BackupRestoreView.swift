import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var snapshot: BackupSnapshot?
    @State private var summary: BackupService.ImportSummary?
    @State private var showFilePicker = false
    @State private var error: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        MascotView(size: 96, mood: summary != nil ? .happy : .think, tone: .terra)
                            .padding(.top, 12)

                        Text(summary != nil ? "Wiederhergestellt!" : "Backup wiederherstellen")
                            .font(.display(28))
                            .foregroundStyle(Color.inkPrimary)

                        if let s = summary {
                            successCard(s)
                            doneButton
                        } else if let snap = snapshot {
                            previewCard(snap)
                            Text("Bestehende Daten bleiben erhalten. Neue Einträge werden ergänzt, existierende Produkte aktualisiert.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.inkSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                                .fixedSize(horizontal: false, vertical: true)
                            applyButton(snap)
                        } else {
                            Text("Wähle eine .json-Datei, die du zuvor mit Kcal-Kun exportiert hast.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.inkSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                                .fixedSize(horizontal: false, vertical: true)
                            pickButton
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
                    Text("Daten wiederherstellen")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(summary != nil ? "Fertig" : "Abbrechen") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handlePickerResult(result)
            }
        }
    }

    // MARK: - Subviews

    private func previewCard(_ snap: BackupSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            row(icon: "calendar", label: "Erstellt am", value: formatDate(snap.exportedAt))
            Divider().overlay(Color.inkDivider)
            row(icon: "iphone", label: "Gerät", value: snap.deviceName)
            Divider().overlay(Color.inkDivider)
            row(icon: "person.text.rectangle", label: "Profil", value: snap.profile != nil ? "1 Eintrag" : "—")
            Divider().overlay(Color.inkDivider)
            row(icon: "tag", label: "Eigene Produkte", value: "\(snap.products.count)")
            Divider().overlay(Color.inkDivider)
            row(icon: "star", label: "BLV-Favoriten", value: "\(snap.favoriteBLVProducts.count)")
            Divider().overlay(Color.inkDivider)
            row(icon: "book.closed", label: "Tagebuch-Einträge", value: "\(snap.entries.count)")
        }
        .padding(16)
        .heroCardStyle()
        .padding(.horizontal, 28)
    }

    private func successCard(_ s: BackupService.ImportSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            row(icon: "person.text.rectangle", label: "Profil",
                value: s.profileApplied ? "übernommen" : "—")
            Divider().overlay(Color.inkDivider)
            row(icon: "plus.circle", label: "Neue Produkte",      value: "\(s.productsAdded)")
            Divider().overlay(Color.inkDivider)
            row(icon: "arrow.clockwise", label: "Aktualisiert",   value: "\(s.productsUpdated)")
            Divider().overlay(Color.inkDivider)
            row(icon: "star.fill", label: "BLV-Favoriten markiert", value: "\(s.blvFavoritesMarked)")
            Divider().overlay(Color.inkDivider)
            row(icon: "book.closed", label: "Neue Einträge",      value: "\(s.entriesAdded)")
            if s.entriesSkipped > 0 {
                Divider().overlay(Color.inkDivider)
                row(icon: "checkmark.circle", label: "Übersprungen (bereits da)",
                    value: "\(s.entriesSkipped)")
            }
        }
        .padding(16)
        .heroCardStyle()
        .padding(.horizontal, 28)
    }

    private func row(icon: String, label: String, value: String) -> some View {
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

    private var pickButton: some View {
        Button { showFilePicker = true } label: {
            primaryLabel("Datei wählen", systemImage: "doc.badge.arrow.up")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 28)
    }

    private func applyButton(_ snap: BackupSnapshot) -> some View {
        Button { apply(snap) } label: {
            if isImporting {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.terra)
                    .clipShape(Capsule())
            } else {
                primaryLabel("Daten zusammenführen", systemImage: "arrow.merge")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 28)
        .disabled(isImporting)
    }

    private var doneButton: some View {
        Button { dismiss() } label: {
            primaryLabel("Fertig", systemImage: "checkmark")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 28)
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

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            loadPreview(url: url)
        case .failure(let e):
            error = e.localizedDescription
        }
    }

    private func loadPreview(url: URL) {
        error = nil
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let snap = try BackupService.preview(data: data)
            snapshot = snap
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func apply(_ snap: BackupSnapshot) {
        isImporting = true
        error = nil
        do {
            let result = try BackupService.apply(snap, context: context)
            summary = result
            snapshot = nil
        } catch {
            self.error = error.localizedDescription
        }
        isImporting = false
    }

    private func formatDate(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.wide).year().hour().minute()
            .locale(Locale(identifier: "de_CH")))
    }
}
