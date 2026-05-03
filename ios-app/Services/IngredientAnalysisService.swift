import Foundation

struct AnalyzeIngredientsRequest: Codable {
    let type: String
    let imageBase64: String
    let mimeType: String
}

struct AnalyzedTotals: Codable {
    var kcal: Double?
    var protein: Double?
}

struct AnalyzeIngredientsResponse: Codable, Identifiable {
    var id = UUID()

    let ingredients: [AnalyzedIngredient]
    let totals: IngredientTotals
    let confidence: String
    let notes: [String]

    enum CodingKeys: String, CodingKey {
        case ingredients
        case totals
        case confidence
        case notes
    }
}

struct IngredientTotals: Codable {
    let kcal: Double?
    let protein: Double?
}

struct AnalyzedIngredient: Codable, Identifiable {
    var id = UUID()

    let name: String
    let amount: Double?
    let unit: String?
    let estimatedKcal: Double?
    let estimatedProtein: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case amount
        case unit
        case estimatedKcal
        case estimatedProtein
    }
}


final class IngredientAnalysisService {
    private let apiClient: APIClient

    init(apiClient: APIClient) { self.apiClient = apiClient }

    func analyze(token: String, jpegBase64: String) async throws -> AnalyzeIngredientsResponse {
        let body = try JSONEncoder().encode(AnalyzeIngredientsRequest(type: "image", imageBase64: jpegBase64, mimeType: "image/jpeg"))
        return try await apiClient.request(path: "api/ai/analyze-ingredients", method: "POST", token: token, body: body)
    }
}
