import SwiftUI

struct ScannerView: View {
    @State private var vm = ScannerViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Scanner")
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
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            loadingView
        } else if let error = vm.scanError {
            errorView(error)
        } else {
            idleView
        }
    }

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("Nährwerttabelle scannen")
                .font(.title2)
                .foregroundStyle(.secondary)
            Button {
                vm.showCamera = true
            } label: {
                Label("Scan starten", systemImage: "camera")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            if let image = vm.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            ProgressView()
                .scaleEffect(1.4)
            Text("Gemini analysiert…")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func errorView(_ error: GeminiServiceError) -> some View {
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
                vm.reset()
                vm.showCamera = true
            } label: {
                Label("Nochmals versuchen", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
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
            Spacer()
        }
    }
}

#Preview {
    ScannerView()
}
