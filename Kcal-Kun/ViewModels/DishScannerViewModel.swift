import SwiftUI

@Observable
@MainActor
final class DishScannerViewModel {
    var showCamera   = false
    var isLoading    = false
    var error: GeminiServiceError? = nil
    var showResults  = false

    var dishName     = ""
    var grams        = 0.0

    private(set) var kcalPer100g    = 0.0
    private(set) var proteinPer100g = 0.0
    private(set) var fatPer100g     = 0.0
    private(set) var carbsPer100g   = 0.0
    private(set) var fiberPer100g   = 0.0

    var kcalTotal:    Double { kcalPer100g    * grams / 100 }
    var proteinTotal: Double { proteinPer100g * grams / 100 }
    var fatTotal:     Double { fatPer100g     * grams / 100 }
    var carbsTotal:   Double { carbsPer100g   * grams / 100 }
    var fiberTotal:   Double { fiberPer100g   * grams / 100 }

    func processImage(_ image: UIImage) async {
        isLoading = true
        error = nil

        let scaled   = scaleImage(image, maxSide: 1024)
        let jpegData = scaled.jpegData(compressionQuality: 0.85) ?? Data()

        do {
            let result = try await GeminiService.analyzeDish(from: jpegData)
            let g = max(result.estimatedGrams, 1)
            dishName        = result.name
            grams           = g
            kcalPer100g    = result.kcal    / g * 100
            proteinPer100g = result.protein / g * 100
            fatPer100g     = result.fat     / g * 100
            carbsPer100g   = result.carbs   / g * 100
            fiberPer100g   = result.fiber   / g * 100
            showResults    = true
        } catch let e as GeminiServiceError {
            error = e
        } catch {
            self.error = .invalidResponse
        }

        isLoading = false
    }

    func reset() {
        dishName        = ""
        grams           = 0
        kcalPer100g    = 0; proteinPer100g = 0
        fatPer100g     = 0; carbsPer100g   = 0; fiberPer100g = 0
        showResults    = false
        error          = nil
        isLoading      = false
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
