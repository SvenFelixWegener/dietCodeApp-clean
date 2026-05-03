import Foundation
import Combine
internal import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var day: DayData?
    @Published var addMealSelection = mealTypes.first!
    @Published var searchTerm = ""
    @Published var searchResults: [Product] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false

    @Published var ingredientAnalysis: AnalyzeIngredientsResponse?
    @Published var isAnalyzingIngredients = false


    func load(container: AppContainer, token: String, date: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            day = try await container.dayService.loadDay(token: token, date: date)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchProducts(container: AppContainer, token: String) async {
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchTerm.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await container.productService.search(token: token, query: trimmedSearchTerm)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyScannedBarcode(_ scannedCode: String, container: AppContainer, token: String) async {
        searchTerm = normalizedBarcode(scannedCode)
        await searchProducts(container: container, token: token)
    }

    private func normalizedBarcode(_ rawValue: String) -> String {
        let cleaned = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count == 13, cleaned.hasPrefix("0") {
            return String(cleaned.dropFirst())
        }
        return cleaned
    }

    func addProduct(_ product: Product, grams: Double = 100) {
        guard var day else { return }
        var entries = day.meals[addMealSelection] ?? []
        entries.append(
            MealEntry(
                id: UUID().uuidString,
                food: product.productName,
                kcal: product.kcalPer100g * grams / 100,
                grams: grams,
                protein: product.proteinPer100g * grams / 100
            )
        )
        day.meals[addMealSelection] = entries
        self.day = day
    }

    func deleteEntries(at offsets: IndexSet, meal: String) {
        guard var day else { return }
        var entries = day.meals[meal] ?? []
        entries.remove(atOffsets: offsets)
        day.meals[meal] = entries
        self.day = day
    }


    func deleteEntry(_ entryID: String, meal: String) {
        guard var day else { return }
        var entries = day.meals[meal] ?? []
        entries.removeAll { $0.id == entryID }
        day.meals[meal] = entries
        self.day = day
    }

    func duplicateEntry(_ entryID: String, meal: String) {
        guard var day else { return }
        guard let original = (day.meals[meal] ?? []).first(where: { $0.id == entryID }) else { return }
        var copy = original
        copy.id = UUID().uuidString
        day.meals[meal, default: []].append(copy)
        self.day = day
    }

    func updateEntry(_ entryID: String, meal: String, grams: Double) {
        guard var day else { return }
        guard let idx = day.meals[meal]?.firstIndex(where: { $0.id == entryID }) else { return }
        var entry = day.meals[meal]![idx]
        let kcalPerGram = entry.kcal / max(entry.grams, 1)
        let proteinPerGram = entry.protein / max(entry.grams, 1)
        entry.grams = grams
        entry.kcal = kcalPerGram * grams
        entry.protein = proteinPerGram * grams
        day.meals[meal]![idx] = entry
        self.day = day
    }


    func analyzeIngredientsImage(container: AppContainer, token: String, imageData: Data) async -> AnalyzeIngredientsResponse? {
        isAnalyzingIngredients = true
        defer { isAnalyzingIngredients = false }
        do {
            let resized = ImageCompressor.jpegDataForUpload(from: imageData)
            ingredientAnalysis = try await container.ingredientAnalysisService.analyze(token: token, jpegBase64: resized.base64EncodedString())
            return ingredientAnalysis
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func addAnalyzedIngredientsToMeal(meal: String, selected: [AnalyzedIngredient], confidence: String, notes: [String]) {
        guard var day else { return }
        let groupId = UUID().uuidString
        let entries: [MealEntry] = selected.map { ingredient in
            let grams = IngredientAmountMapper.grams(amount: ingredient.amount, unit: ingredient.unit)
            let kcal = ingredient.estimatedKcal ?? 0
            let protein = ingredient.estimatedProtein ?? 0
            return MealEntry(id: UUID().uuidString, food: ingredient.name, kcal: kcal, grams: grams, protein: protein, groupId: groupId, groupType: "ai_ingredients", groupTitle: "AI Zutatenliste", source: "ai_image", confidence: confidence, notes: notes)
        }
        day.meals[meal, default: []].append(contentsOf: entries)
        self.day = day
    }

    func save(container: AppContainer, token: String) async {
        guard let day else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await container.dayService.saveDay(token: token, day: day)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


enum IngredientAmountMapper {
    static func grams(amount: Double?, unit: String?) -> Double {
        guard let amount else { return 100 }
        let u = (unit ?? "g").lowercased()
        if ["kg", "kilogramm"].contains(u) { return amount * 1000 }
        if ["ml"].contains(u) { return amount }
        return amount
    }
}

enum ImageCompressor {
    static func jpegDataForUpload(from imageData: Data) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: imageData) else { return imageData }
        let resized = resize(image: image, maxEdge: 1600)
        return resized.jpegData(compressionQuality: 0.75) ?? imageData
        #else
        return imageData
        #endif
    }

    #if canImport(UIKit)
    private static func resize(image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(1, maxEdge / max(size.width, size.height))
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
    #endif
}
