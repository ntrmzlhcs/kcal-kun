import SwiftUI
import SwiftData

struct ScannerView: View {
    @State private var vm = ScannerViewModel()
    @State private var dishVm = DishScannerViewModel()
    @State private var dishCapturedImage: UIImage? = nil
    @State private var showDishDisclaimer = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Scanner")
                        .font(.display(18))
                        .foregroundStyle(Color.inkPrimary)
                }
            }
            // Nährwerttabellen-Scanner
            .sheet(isPresented: $vm.showCamera) {
                CameraPickerView(selectedImage: $vm.capturedImage)
                    .ignoresSafeArea()
                    .onDisappear {
                        if let image = vm.capturedImage {
                            Task { await vm.processImage(image) }
                        }
                    }
            }
            .sheet(isPresented: $vm.showConfirmation, onDismiss: { vm.reset() }) {
                if let result = vm.scanResult {
                    ScanConfirmationView(vm: vm, result: result)
                }
            }
            // Gericht-Analyse
            .sheet(isPresented: $dishVm.showCamera) {
                CameraPickerView(selectedImage: $dishCapturedImage)
                    .ignoresSafeArea()
                    .onDisappear {
                        if let image = dishCapturedImage {
                            Task { await dishVm.processImage(image) }
                            dishCapturedImage = nil
                        }
                    }
            }
            .sheet(isPresented: $dishVm.showResults, onDismiss: { dishVm.reset() }) {
                DishScanResultView(vm: dishVm)
            }
            .alert("KI-Schätzung: Hinweis", isPresented: $showDishDisclaimer) {
                Button("Weiter") { dishVm.showCamera = true }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("KI-Analysen von Gerichten können Kalorien um ±20–35 % über- oder unterschätzen — je nach Komplexität und Bildqualität. Das Ergebnis ist eine Annäherung. Überprüfe und passe die Werte im nächsten Schritt an.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let isLoading = vm.isLoading || dishVm.isLoading
        if isLoading {
            loadingView
        } else if let error = vm.scanError {
            errorView(error, scanType: .label)
        } else if let error = dishVm.error {
            errorView(error, scanType: .dish)
        } else {
            idleView
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text("Etikett scannen")
                        .font(.display(38))
                        .foregroundStyle(Color.inkPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)

                // Scanner card with mascot
                scannerCard(isLoading: false)

                // CTA buttons
                VStack(spacing: 10) {
                    Button {
                        vm.showCamera = true
                    } label: {
                        Label("Nährwerttabelle scannen", systemImage: "barcode.viewfinder")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.terra)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.terra.opacity(0.32), radius: 18, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDishDisclaimer = true
                    } label: {
                        Label("Gericht analysieren", systemImage: "frying.pan")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cardBackground)
                            .foregroundStyle(Color.warmBrown)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color(hex: 0x7C5E3C).opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)

                Spacer().frame(height: 90)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Etikett scannen")
                        .font(.display(38))
                        .foregroundStyle(Color.inkPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)

                scannerCard(isLoading: true)

                // Loading indicator
                VStack(spacing: 10) {
                    Text("Kcal-Kun analysiert …")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.inkSecondary)
                    LoadingDots()
                }
                .padding(16)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.inkDivider, lineWidth: 1))
                .padding(.horizontal, 18)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Scanner Card

    @ViewBuilder
    private func scannerCard(isLoading: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            // Nutrition label prop
            VStack(alignment: .leading, spacing: 0) {
                Text("NÄHRWERTE / 100g")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.bottom, 4)
                Divider().overlay(Color.inkDivider)
                    .padding(.bottom, 4)
                Group {
                    labelLine("Energie", "142 kcal")
                    labelLine("Fett", "4.2 g")
                    labelLine("KH", "18.5 g")
                    labelLine("Protein", "8.1 g")
                    labelLine("Salz", "0.3 g")
                }
                // Scan line animation
                if isLoading {
                    ScanLine()
                }
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Color.inkPrimary.opacity(0.7))
            .padding(14)
            .frame(width: 160, height: 210)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color(hex: 0x7C5E3C).opacity(0.18), lineWidth: 1))
            .shadow(color: Color(hex: 0x7C5E3C).opacity(0.12), radius: 18, x: 0, y: 8)
            .rotationEffect(.degrees(-4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 28)

            // Mascot peeking
            VStack(spacing: 0) {
                if isLoading {
                    SpeechBubble(text: "hmm, ich lese …")
                        .padding(.trailing, 20)
                }
                MascotView(size: 120, mood: isLoading ? .scan : .happy, tone: .cream, tilt: -8)
                    .bobAnimation(active: isLoading)
            }
            .padding(.trailing, 8)
            .padding(.bottom, -10)
        }
        .frame(height: 240)
        .padding(24)
        .background(
            LinearGradient(colors: [Color.beige, Color.appBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color(hex: 0x7C5E3C).opacity(0.10), lineWidth: 1))
        .shadow(color: Color(hex: 0x7C5E3C).opacity(0.08), radius: 28, x: 0, y: 12)
        .padding(.horizontal, 18)
    }

    private func labelLine(_ key: String, _ val: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(val)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Error View

    private enum ScanType { case label, dish }

    private func errorView(_ error: GeminiServiceError, scanType: ScanType) -> some View {
        VStack(spacing: 24) {
            Spacer()
            MascotView(size: 80, mood: .think, tone: .beige)
            Text(error.localizedDescription)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.inkSecondary)
                .padding(.horizontal, 32)

            VStack(spacing: 10) {
                Button {
                    switch scanType {
                    case .label: vm.reset(); vm.showCamera = true
                    case .dish:  dishVm.error = nil; showDishDisclaimer = true
                    }
                } label: {
                    Label("Nochmals versuchen", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.terra)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.terra.opacity(0.28), radius: 14, x: 0, y: 6)
                }
                .buttonStyle(.plain)

                if scanType == .label {
                    Button {
                        vm.scanError = nil
                        vm.openManualEntry()
                    } label: {
                        Label("Manuell eingeben", systemImage: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.cardBackground)
                            .foregroundStyle(Color.warmBrown)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color(hex: 0x7C5E3C).opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            Spacer()
        }
    }
}

// MARK: - Supporting Views

private struct SpeechBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Color.inkSecondary)
            .italic()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: 0x7C5E3C).opacity(0.15), lineWidth: 1))
    }
}

private struct ScanLine: View {
    @State private var offset: CGFloat = 0
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.terra)
                .frame(height: 2)
                .shadow(color: Color.terra, radius: 4)
                .offset(y: offset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                        offset = geo.size.height - 2
                    }
                }
        }
    }
}

private struct LoadingDots: View {
    @State private var phase = 0.0
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.terra)
                    .frame(width: 6, height: 6)
                    .scaleEffect(dotScale(i))
                    .opacity(dotOpacity(i))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 3
            }
        }
    }

    private func dotScale(_ i: Int) -> CGFloat {
        let p = (phase - Double(i) * 0.4).truncatingRemainder(dividingBy: 3)
        return p < 1 ? 0.8 + p * 0.2 : p < 2 ? 1.0 - (p - 1) * 0.2 : 0.8
    }

    private func dotOpacity(_ i: Int) -> Double {
        let p = (phase - Double(i) * 0.4).truncatingRemainder(dividingBy: 3)
        return p < 1 ? 0.3 + p * 0.7 : p < 2 ? 1.0 - (p - 1) * 0.7 : 0.3
    }
}

private extension View {
    func bobAnimation(active: Bool) -> some View {
        modifier(BobAnimationModifier(active: active))
    }
}

private struct BobAnimationModifier: ViewModifier {
    let active: Bool
    @State private var bobOffset: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .offset(y: bobOffset)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    bobOffset = -6
                }
            }
    }
}

#Preview {
    ScannerView()
}
