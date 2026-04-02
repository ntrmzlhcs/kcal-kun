import SwiftUI
import SwiftData

struct ScannerView: View {
    @Query(sort: \Product.name) private var allProducts: [Product]

    @State private var vm = ScannerViewModel()
    @State private var mealVm = MealScannerViewModel()
    @State private var dishVm = DishScannerViewModel()
    @State private var mealCapturedImage: UIImage? = nil
    @State private var dishCapturedImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Scanner")
                // --- Nährwerttabellen-Scanner ---
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
                // --- Mahlzeit-Analyse ---
                .sheet(isPresented: $mealVm.showCamera) {
                    CameraPickerView(selectedImage: $mealCapturedImage)
                        .ignoresSafeArea()
                        .onDisappear {
                            if let image = mealCapturedImage {
                                Task { await mealVm.processImage(image, allProducts: allProducts) }
                                mealCapturedImage = nil
                            }
                        }
                }
                .sheet(isPresented: $mealVm.showResults, onDismiss: { mealVm.reset() }) {
                    MealScanResultView(vm: mealVm)
                }
                // --- Gericht-Analyse ---
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
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading || mealVm.isLoading || dishVm.isLoading {
            loadingView
        } else if let error = vm.scanError {
            errorView(error, scanType: .label)
        } else if let error = mealVm.error {
            errorView(error, scanType: .meal)
        } else if let error = dishVm.error {
            errorView(error, scanType: .dish)
        } else {
            idleView
        }
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Button {
                vm.showCamera = true
            } label: {
                Label("Nährwerttabelle scannen", systemImage: "barcode.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Button {
                mealVm.showCamera = true
            } label: {
                Label("Mahlzeit analysieren", systemImage: "fork.knife.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 40)

            Button {
                dishVm.showCamera = true
            } label: {
                Label("Gericht analysieren", systemImage: "frying.pan")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            Text("Gemini analysiert…")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private enum ScanType { case label, meal, dish }

    private func errorView(_ error: GeminiServiceError, scanType: ScanType) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button {
                switch scanType {
                case .label: vm.reset(); vm.showCamera = true
                case .meal:  mealVm.error = nil; mealVm.showCamera = true
                case .dish:  dishVm.error = nil; dishVm.showCamera = true
                }
            } label: {
                Label("Nochmals versuchen", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            if scanType == .label {
                Button {
                    vm.scanError = nil
                    vm.openManualEntry()
                } label: {
                    Label("Manuell eingeben", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 40)
            }
            Spacer()
        }
    }
}

#Preview {
    ScannerView()
}
