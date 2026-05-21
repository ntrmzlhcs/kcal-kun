import SwiftUI
import SwiftData

@Observable
@MainActor
final class ScannerViewModel {
    var showCamera = false
    var capturedImage: UIImage? = nil
    var scanResult: NutritionScanResult? = nil
    var isLoading = false
    var scanError: GeminiServiceError? = nil
    var showConfirmation = false

    func processImage(_ image: UIImage) async {
        capturedImage = image
        isLoading = true
        scanError = nil

        let jpegData = scaleImage(image, maxSide: 1024).jpegData(compressionQuality: 0.85) ?? Data()

        do {
            scanResult = try await GeminiService.extractNutrition(from: jpegData)
            showConfirmation = true
        } catch let e as GeminiServiceError {
            scanError = e
        } catch {
            scanError = .invalidResponse
        }

        isLoading = false
    }

    func openManualEntry() {
        scanResult = NutritionScanResult()
        showConfirmation = true
    }

    /// Speichert das gescannte Produkt. Wenn `barcode` gesetzt ist (z. B. weil
    /// der User aus dem Barcode-Not-Found-Flow heraus über OCR erfasst hat),
    /// wird er auf das Product geschrieben — damit der nächste Scan denselben
    /// Code lokal findet.
    func saveProduct(name: String, result: NutritionScanResult, context: ModelContext, barcode: String? = nil) {
        let product = Product(
            name: name,
            kcalPer100g: result.kcalPer100g ?? 0,
            proteinPer100g: result.proteinPer100g ?? 0,
            fatPer100g: result.fatPer100g ?? 0,
            carbsPer100g: result.carbsPer100g ?? 0,
            fiberPer100g: result.fiberPer100g,
            sugarPer100g: result.sugarPer100g,
            saltPer100g: result.saltPer100g,
            source: .ocr,
            barcode: barcode
        )
        context.insert(product)
        try? context.save()
        reset()
    }

    func reset() {
        capturedImage = nil
        scanResult = nil
        showConfirmation = false
        scanError = nil
        isLoading = false
    }

    private func scaleImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxSide else { return image }

        let scale = maxSide / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
