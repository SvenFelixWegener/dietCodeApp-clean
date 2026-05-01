import Foundation

let mealTypes = ["Frühstück", "Vormittag", "Mittag", "Nachmittag", "Abend", "Snack"]

struct LoginResponse: Codable {
    let ok: Bool
    let token: String
    let userHash: String
    let expiresAt: Int
}

struct DayData: Codable {
    let date: String
    var meals: [String: [MealEntry]]
    var goals: Goals
}

struct Goals: Codable {
    var kcal: Double
    var protein: Double
}

struct MealEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var productId: String
    var productName: String
    var brand: String
    var code: String?
    var grams: Double
    var kcalPer100g: Double
    var proteinPer100g: Double

    var kcal: Double { kcalPer100g * grams / 100 }
    var protein: Double { proteinPer100g * grams / 100 }

    enum CodingKeys: String, CodingKey {
        case productId, productName, brand, code, grams, kcalPer100g, proteinPer100g
    }
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
