import Foundation

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var day: DayData?
    @Published var selectedMeal = mealTypes.first!
    @Published var searchTerm = ""
    @Published var searchResults: [Product] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSaving = false

    func load(container: AppContainer, token: String, date: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            day = try await container.dayService.loadDay(token: token, date: date)
        } catch { errorMessage = error.localizedDescription }
    }

    func searchProducts(container: AppContainer, token: String) async {
        guard !searchTerm.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            searchResults = try await container.productService.search(token: token, food: searchTerm)
        } catch { errorMessage = error.localizedDescription }
    }

    func addProduct(_ product: Product, grams: Double = 100) {
        guard var day else { return }
        var entries = day.meals[selectedMeal] ?? []
        entries.append(MealEntry(productId: product.productId, productName: product.productName, brand: product.brand, code: product.code, grams: grams, kcalPer100g: product.kcalPer100g, proteinPer100g: product.proteinPer100g))
        day.meals[selectedMeal] = entries
        self.day = day
    }

    func save(container: AppContainer, token: String) async {
        guard let day else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await container.dayService.saveDay(token: token, day: day)
        } catch { errorMessage = error.localizedDescription }
    }
}
