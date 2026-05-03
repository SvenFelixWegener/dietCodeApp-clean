import Foundation

let mealTypes = ["Frühstück", "Vormittag", "Mittag", "Nachmittag", "Abend", "Snack"]

struct LoginResponse: Codable {
    let ok: Bool
    let token: String
    let userHash: String
    let expiresAt: Int
}

struct DayData: Codable {
    var date: String
    var meals: [String: [MealEntry]]
}

struct Goals: Codable {
    var kcal: Double
    var protein: Double
}

struct MealEntry: Codable, Identifiable {
    var id: String
    var food: String
    var kcal: Double
    var grams: Double
    var protein: Double
    var groupId: String? = nil
    var groupType: String? = nil
    var groupTitle: String? = nil
    var source: String? = nil
    var confidence: String? = nil
    var notes: [String]? = nil
}

struct ProductSearchResponse: Codable {
    let products: [Product]
    let source: String?
}

struct Product: Codable, Identifiable {
    var id: String { productId }
    let productId: String
    let productName: String
    let brand: String
    let code: String?
    let kcalPer100g: Double
    let proteinPer100g: Double
}
