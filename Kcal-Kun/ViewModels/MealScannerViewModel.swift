import SwiftUI
import SwiftData

struct MealComponent: Identifiable {
    let id = UUID()
    var blvName: String
    var grams: Double
    var isSelected: Bool = true
    var matchedProduct: Product? = nil
}

@Observable
@MainActor
final class MealScannerViewModel {
    var showCamera = false
    var showPhotoPicker = false
    var isLoading = false
    var components: [MealComponent] = []
    var error: GeminiServiceError? = nil
    var showResults = false

    func processImage(_ image: UIImage, allProducts: [Product]) async {
        isLoading = true
        error = nil

        let blvProducts = allProducts.filter { $0.source == .preloaded }
        let blvNames = blvProducts.map { $0.name }

        let scaled = scaleImage(image, maxSide: 1024)
        let jpegData = scaled.jpegData(compressionQuality: 0.85) ?? Data()

        do {
            let raw = try await GeminiService.analyzeMeal(from: jpegData, blvNames: blvNames)
            components = raw.map { item in
                let matched = allProducts.first { $0.name == item.blvName }
                return MealComponent(blvName: item.blvName, grams: item.grams, matchedProduct: matched)
            }
            showResults = true
        } catch let e as GeminiServiceError {
            error = e
        } catch {
            self.error = .invalidResponse
        }

        isLoading = false
    }

    func reset() {
        components = []
        showResults = false
        error = nil
        isLoading = false
    }

    private func scaleImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxSide else { return image }
        let scale = maxSide / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
