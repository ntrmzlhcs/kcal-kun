import SwiftUI
import SafariServices

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// „Über die App"-Screen — zeigt App-Info, Legal-Links und Hinweise zum eigenen
/// Gemini-API-Key. Erreichbar via Profil → Sektion „App".
struct AboutAppView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var safariURL: URL?

    // GitHub-Pages URLs (siehe docs/legal/ im gleichen Repo, deployed via main /docs)
    private let privacyURL    = URL(string: "https://ntrmzlhcs.github.io/kcal-kun/legal/privacy.html")!
    private let imprintURL    = URL(string: "https://ntrmzlhcs.github.io/kcal-kun/legal/imprint.html")!
    private let termsURL      = URL(string: "https://ntrmzlhcs.github.io/kcal-kun/legal/terms.html")!
    private let geminiHelpURL = URL(string: "https://aistudio.google.com/app/apikey")!

    @AppStorage("selectedMascotTone") private var savedMascotTone = "cream"

    private var mascotTone: MascotTone {
        switch savedMascotTone {
        case "terra": return .terra
        case "beige": return .beige
        default:      return .cream
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        appHeader
                        legalSection
                        geminiSection
                        creditsSection
                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Über die App")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
            .sheet(item: $safariURL) { url in
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        VStack(spacing: 12) {
            MascotView(size: 80, mood: .happy, tone: mascotTone)
                .padding(.top, 6)
            Text("Kcal-Kun")
                .font(.display(32))
                .foregroundStyle(Color.inkPrimary)
            Text("Cozy Kalorientagebuch")
                .font(.system(size: 14))
                .foregroundStyle(Color.inkSecondary)
            Text(appVersion)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.inkTertiary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .heroCardStyle()
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Rechtliches")
            VStack(spacing: 0) {
                legalRow(icon: "lock.shield", label: "Datenschutz",
                         sublabel: "Was passiert mit deinen Daten?",
                         tint: .terra) { safariURL = privacyURL }
                Divider().padding(.leading, 14)
                legalRow(icon: "building.2", label: "Impressum",
                         sublabel: "Anbieterangaben",
                         tint: .warmBrown) { safariURL = imprintURL }
                Divider().padding(.leading, 14)
                legalRow(icon: "doc.text", label: "Nutzungsbedingungen",
                         sublabel: "AGB inkl. KI-Disclaimer",
                         tint: .warmBrown) { safariURL = termsURL }
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.inkDivider, lineWidth: 1))
        }
    }

    // MARK: - Gemini

    private var geminiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "KI-Funktionen")
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.forest)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Drei Funktionen nutzen Google Gemini")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("OCR-Scanner, Gericht-Analyse und KI-Ernährungsanalyse. Alle senden Daten direkt von deinem iPhone an Google — mit deinem eigenen API-Key. Wir sehen nichts davon.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    safariURL = geminiHelpURL
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Wie bekomme ich einen Gemini-API-Key?")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.warmBrown)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.beige.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.warmBrown.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkTertiary)
                    Text("Schätzungen können Fehler enthalten — siehe AGB.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkTertiary)
                    Spacer()
                }
            }
            .padding(14)
            .heroCardStyle()
        }
    }

    // MARK: - Credits

    private var creditsSection: some View {
        VStack(spacing: 12) {
            // Daten-Attribution
            VStack(spacing: 4) {
                Text("Lebensmittel-Daten")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                Button {
                    safariURL = URL(string: "https://world.openfoodfacts.org")
                } label: {
                    Text("Open Food Facts (ODbL-Lizenz)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.warmBrown)
                        .underline()
                }
                .buttonStyle(.plain)
                Text("Schweizer Lebensmittel: BLV-Datenbank")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkTertiary)
            }

            VStack(spacing: 4) {
                Text("Gemacht mit ❤ in der Schweiz")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkSecondary)
                Text("© Martin Schulz")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    // MARK: - Row Helper

    @ViewBuilder
    private func legalRow(icon: String, label: String, sublabel: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(sublabel)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SafariView Wrapper

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredBarTintColor = UIColor(Color.appBackground)
        vc.preferredControlTintColor = UIColor(Color.warmBrown)
        return vc
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
