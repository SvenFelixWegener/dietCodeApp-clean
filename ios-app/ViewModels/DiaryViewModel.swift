import Foundation
import Combine
internal import SwiftUI

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var day: DayData?
    @Published var addMealSelection = mealTypes.first!
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchProducts(container: AppContainer, token: String) async {
        guard !searchTerm.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            searchResults = try await container.productService.search(token: token, food: searchTerm)
        } catch {
            errorMessage = error.localizedDescription
        }
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
